// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {AccessControl} from "lib/openzeppelin-contracts/contracts/access/AccessControl.sol";

contract CarbonCreditSystem is ERC20, AccessControl {
    // 初始化角色
    bytes32 public constant GOVERNMENT_ROLE = keccak256("GOVERNMENT_ROLE");
    bytes32 public constant VALIDATOR_OPERATOR = keccak256("VALIDATOR_OPERATOR");
    bytes32 public constant VALIDATOR_ENTERPRISE = keccak256("VALIDATOR_ENTERPRISE");

    // 最小质押金额
    uint256 public minStakeAmount;
    // 国库地址 - 接收罚金和系统费用的地址
    address public treasury;
    // 任务计数器 - 用于生成唯一任务ID的计数器
    uint256 public taskCounter;

    //事件
    // 运营商初始化事件 - 当政府成功初始化运营商身份并发放初始代币时触发
    // @param operator 被初始化的运营商地址（索引字段，便于日志过滤）
    // @param amount 政府发放的初始代币数量
    event OperatorInitialized(address indexed operator, uint256 amount);

    // 质押操作事件 - 当运营商增加质押金额时触发
    // @param operator 执行质押操作的运营商地址（索引字段，便于日志过滤）
    // @param amount 质押金额的变化量（正数表示增加，负数表示减少）
    event StakeAdded(address indexed operator, uint256 amount);
    event StakeRemoved(address indexed operator, uint256 amount);

    // 记录出售碳积分事件 - 当运营商成功向企业出售碳积分时触发
    // @param operator 出售碳积分的运营商地址（索引字段，便于日志过滤和查询）
    // @param enterprise 购买碳积分的企业地址（索引字段，便于日志过滤和查询）
    // @param amount 出售的碳积分数量
    // @param timestamp 交易发生的时间戳
    event CarbonCreditSold(address indexed operator, address indexed enterprise, uint256 amount, uint256 timestamp);

    // 企业初始化事件 - 当政府成功初始化企业身份并将其添加到白名单时触发
    // @param enterprise 被初始化的企业地址（索引字段，便于日志过滤和查询）
    // 触发时机：政府调用 initializeEnterprise() 函数成功完成企业身份初始化
    event EnterpriseInitialized(address indexed enterprise);

    // 企业碳积分使用事件 - 当企业成功使用（销毁）碳积分时触发
    // @param enterprise 使用碳积分的企业地址（索引字段，便于按企业查询使用记录）
    // @param amount 使用的碳积分数量
    // 触发时机：企业调用 useCarbonCredits() 函数成功销毁指定数量的碳积分
    event EnterpriseCarbonUsed(address indexed enterprise, uint256 amount);
    // 碳积分 Mint 事件 - 当政府根据调度结果向运营商发放碳积分时触发
    // @param operator 接收碳积分的运营商地址（索引字段，便于日志过滤和查询）
    // @param carbonAmount 发放的碳积分数量
    // @param taskId 关联的调度任务ID
    // @param timestamp 碳积分发放的时间戳
    event CarbonCreditMinted(address indexed operator, uint256 carbonAmount, uint256 taskId, uint256 timestamp);
    // 运营商惩罚事件 - 当政府对违规运营商进行惩罚时触发
    // @param operator 被惩罚的运营商地址（索引字段，便于日志过滤和查询）
    // @param penaltyAmount 实际扣除的惩罚金额
    // @param newReputation 惩罚后运营商的最新信誉评分
    // @param timestamp 惩罚发生的时间戳
    event OperatorPenalized(address indexed operator, uint256 penaltyAmount, uint8 newReputation, uint256 timestamp);
    // 运营商暂停事件 - 当政府暂停某个运营商的资格时触发
    // @param operator 被暂停的运营商地址（索引字段，便于日志过滤和查询）
    // @param timestamp 暂停发生的时间戳
    event OperatorSuspended(address indexed operator, uint256 timestamp);
    // 运营商恢复事件 - 当政府恢复某个被暂停的运营商资格时触发
    // @param operator 被恢复的运营商地址（索引字段，便于日志过滤和查询）
    // @param timestamp 恢复发生的时间戳
    event OperatorRestored(address indexed operator, uint256 timestamp);
    // 运营商移除事件 - 当政府永久移除某个严重违规的运营商时触发
    // @param operator 被移除的运营商地址（索引字段，便于日志过滤和查询）
    // @param stakedAmount 被没收的质押金额
    // @param timestamp 移除发生的时间戳
    event OperatorRemoved(address indexed operator, uint256 stakedAmount, uint256 timestamp);
    // 调度结果结构体

    struct DishpatchResult {
        uint256 taskId; // 任务ID
        address operator; // 运营商地址
        uint256 carbonCredit; // 碳积分（由后端计算好）
        uint256 timestamp; // 时间戳
    }

    // 运营商信息
    struct Operator {
        uint256 stakedAmount; // 质押金额
        uint256 totalCarbon; // 总碳积分
        uint8 reputation; // 信誉评分 (0-100)
        bool isActive; // 是否活跃
    }

    // 企业碳积分账户
    struct CarbonAccount {
        uint256 currentBalance; // 当前碳积分余额
        uint256 totalPurchased; // 累计购买总量
        uint256 totalUsed; // 累计使用总量
        bool isActive; // 是否活跃
    }

    // ========== 运营商相关状态变量 ==========
    // 运营商地址到运营商信息的映射 - 存储所有注册运营商的基本信息和状态
    mapping(address => Operator) public operators;

    // 任务ID到调度结果的映射 - 存储所有调度任务的详细结果数据
    mapping(uint256 => DishpatchResult) public dispatchResults;

    // 运营商地址到白名单状态的映射 - 记录哪些运营商地址已被政府批准加入系统
    mapping(address => bool) public whitelistedOperators;

    // ========== 企业相关状态变量 ==========
    mapping(address => CarbonAccount) public carbonAccounts;
    mapping(address => bool) public whitelistedEnterprises;

    constructor(uint256 _minStakeAmount, address government) ERC20("CarbonCredit", "CC") {
        _grantRole(GOVERNMENT_ROLE, government);
        minStakeAmount = _minStakeAmount;
        treasury = government;
        taskCounter = 0;
    }

    // ========== 政府初始化运营商身份 ==========

    // ========== 政府初始化运营商并完成质押 ==========
    function initializeAndStakeOperator(address operator) external onlyRole(GOVERNMENT_ROLE) {
        require(!operators[operator].isActive, "Operator already active");

        // 发放初始代币给运营商
        _mint(operator, minStakeAmount);

        // 运营商将代币质押到合约
        _transfer(operator, address(this), minStakeAmount);

        // 政府验证的运营商身份
        whitelistedOperators[operator] = true;

        // 初始化运营商信息，并标记为活跃
        operators[operator] =
            Operator({stakedAmount: minStakeAmount, totalCarbon: minStakeAmount, reputation: 50, isActive: true});

        // 授予运营商角色
        _grantRole(VALIDATOR_OPERATOR, operator);

        // 发出事件
        emit OperatorInitialized(operator, minStakeAmount);
    }

    // ========== 运营商管理 ==========

    // 增加质押
    function addStake(uint256 amount) external onlyRole(VALIDATOR_OPERATOR) {
        if (balanceOf(msg.sender) <= amount) {
            revert("Insufficient balance");
        }
        if (!operators[msg.sender].isActive) {
            revert("Operator not active");
        }
        // 转移质押代币
        _transfer(msg.sender, address(this), amount);
        operators[msg.sender].stakedAmount += amount;

        emit StakeAdded(msg.sender, amount);
    }

    // 解除质押（需满足最低质押要求）
    function unstake(uint256 amount) external onlyRole(VALIDATOR_OPERATOR) {
        // 获取运营商信息存储引用
        Operator storage op = operators[msg.sender];

        // 检查运营商是否处于活跃状态
        require(op.isActive, "Operator not active");

        // 检查解除质押金额是否超过当前质押金额
        uint256 minmumStakeAmount = op.stakedAmount - minStakeAmount;
        require(amount <= minmumStakeAmount, "Insufficient staked amount");

        // 检查合约是否有足够的代币余额进行转账
        require(balanceOf(address(this)) >= amount, "Contract insufficient balance");

        // 更新运营商质押金额（先更新状态，防止重入攻击）
        op.stakedAmount -= amount;

        // 将代币从合约转回运营商钱包
        _transfer(address(this), msg.sender, amount);

        // 记录质押减少事件
        emit StakeRemoved(msg.sender, amount);
    }

    // ========== 根据调度结果 Mint 碳积分 ==========

    /**
     * @dev 政府根据调度结果向运营商发放碳积分
     * @param operator 运营商地址
     * @param carbonAmount 发放的碳积分数量
     * @param taskId 任务ID
     * @notice 只有政府可以调用此函数，用于根据实际减排成果发放碳积分
     */
    function mintCarbonCreditBasedOnDispatch(address operator, uint256 carbonAmount, uint256 taskId)
        external
        onlyRole(GOVERNMENT_ROLE)
    {
        // 检查运营商是否在白名单中
        require(whitelistedOperators[operator], "Operator not whitelisted");

        // 检查运营商是否活跃
        require(operators[operator].isActive, "Operator not active");

        // 检查任务ID是否已存在
        require(dispatchResults[taskId].timestamp == 0, "Task ID already exists");

        // 记录调度结果
        dispatchResults[taskId] = DishpatchResult({
            taskId: taskId,
            operator: operator,
            carbonCredit: carbonAmount,
            timestamp: block.timestamp
        });

        // 向运营商发放碳积分
        _mint(operator, carbonAmount);

        // 更新运营商信息
        Operator storage op = operators[operator];
        op.totalCarbon += carbonAmount;

        // 更新信誉评分（根据碳积分发放量增加信誉）
        uint256 reputationIncrease = carbonAmount / 10 ether; // 每10个碳积分增加1点信誉
        if (op.reputation + reputationIncrease <= 100) {
            op.reputation += uint8(reputationIncrease);
        } else {
            op.reputation = 100;
        }

        // 更新任务计数器
        taskCounter++;

        // 触发事件
        emit CarbonCreditMinted(operator, carbonAmount, taskId, block.timestamp);
    }

    // 向白名单企业出售碳积分
    /**
     * @dev 向白名单企业出售碳积分（基础版本）
     * @param enterprise 企业地址
     * @param amount 出售的碳积分数量
     * @notice 运营商只能向白名单企业出售碳积分
     */
    function sellCarbonCredit(address enterprise, uint256 amount) external onlyRole(VALIDATOR_OPERATOR) {
        // 检查运营商是否活跃
        require(operators[msg.sender].isActive, "Operator not active");

        // 检查企业是否在白名单中
        require(whitelistedEnterprises[enterprise], "Enterprise not whitelisted");

        // 检查企业是否活跃
        require(carbonAccounts[enterprise].isActive, "Enterprise not active");

        // 检查运营商是否有足够的碳积分
        require(balanceOf(msg.sender) >= amount, "Insufficient carbon credits");

        // 执行碳积分转移
        bool success = transfer(enterprise, amount);
        require(success, "Transfer failed");

        // 更新企业碳积分账户状态
        CarbonAccount storage enterpriseAccount = carbonAccounts[enterprise];
        enterpriseAccount.currentBalance += amount;
        enterpriseAccount.totalPurchased += amount;

        // 记录交易事件
        emit CarbonCreditSold(msg.sender, enterprise, amount, block.timestamp);
    }

    // ========== 运营商惩罚机制 ==========

    /**
     * @dev 惩罚运营商 - 用于处理违规行为
     * @param operator 被惩罚的运营商地址
     * @param penaltyAmount 惩罚金额（从质押中扣除）
     * @notice 政府可以惩罚违规的运营商，扣除质押并降低信誉
     */
    function penalizeOperator(address operator, uint256 penaltyAmount) external onlyRole(GOVERNMENT_ROLE) {
        require(whitelistedOperators[operator], "Operator not whitelisted");
        require(operators[operator].isActive, "Operator not active");
        require(penaltyAmount > 0, "Penalty amount must be positive");

        Operator storage op = operators[operator];

        // 检查惩罚金额是否超过可用质押
        require(penaltyAmount <= op.stakedAmount, "Penalty exceeds staked amount");

        // 确保惩罚后仍满足最低质押要求
        require(op.stakedAmount - penaltyAmount >= minStakeAmount, "Penalty would make stake below minimum");

        // 扣除质押
        op.stakedAmount -= penaltyAmount;

        // 将罚金转移到国库
        _transfer(address(this), treasury, penaltyAmount);

        // 大幅降低信誉评分
        if (op.reputation >= 30) {
            op.reputation -= 30;
        } else {
            op.reputation = 0;
            // 如果信誉降为0，停用运营商
            op.isActive = false;
            _revokeRole(VALIDATOR_OPERATOR, operator);
        }

        // 触发惩罚事件
        emit OperatorPenalized(operator, penaltyAmount, op.reputation, block.timestamp);
    }

    /**
     * @dev 暂停运营商资格
     * @param operator 被暂停的运营商地址
     * @notice 政府可以暂时停用运营商的资格，但保留其质押和碳积分
     */
    function suspendOperator(address operator) external onlyRole(GOVERNMENT_ROLE) {
        require(whitelistedOperators[operator], "Operator not whitelisted");
        require(operators[operator].isActive, "Operator already inactive");

        Operator storage op = operators[operator];
        op.isActive = false;

        // 触发暂停事件
        emit OperatorSuspended(operator, block.timestamp);
    }

    /**
     * @dev 恢复运营商资格
     * @param operator 被恢复的运营商地址
     * @notice 政府可以恢复之前被暂停的运营商资格
     */
    function restoreOperator(address operator) external onlyRole(GOVERNMENT_ROLE) {
        require(whitelistedOperators[operator], "Operator not whitelisted");
        require(!operators[operator].isActive, "Operator already active");

        Operator storage op = operators[operator];
        op.isActive = true;

        // 触发恢复事件
        emit OperatorRestored(operator, block.timestamp);
    }

    /**
     * @dev 永久移除运营商（严重违规）
     * @param operator 被移除的运营商地址
     * @notice 政府可以永久移除严重违规的运营商，没收全部质押
     */
    function removeOperator(address operator) external onlyRole(GOVERNMENT_ROLE) {
        require(whitelistedOperators[operator], "Operator not whitelisted");

        Operator storage op = operators[operator];

        // 没收全部质押到国库
        if (op.stakedAmount > 0) {
            _transfer(address(this), treasury, op.stakedAmount);
        }

        // 从白名单中移除
        whitelistedOperators[operator] = false;

        // 重置运营商信息
        operators[operator] = Operator({stakedAmount: 0, totalCarbon: 0, reputation: 0, isActive: false});

        // 移除角色
        _revokeRole(VALIDATOR_OPERATOR, operator);

        // 触发移除事件
        emit OperatorRemoved(operator, op.stakedAmount, block.timestamp);
    }

    // ========== 企业管理核心功能 ==========

    // ========== 政府初始化企业身份 ==========

    /**
     * @dev 政府初始化企业身份
     * @param enterprise 企业地址
     */
    function initializeEnterprise(address enterprise) external onlyRole(GOVERNMENT_ROLE) {
        require(!carbonAccounts[enterprise].isActive, "Enterprise already initialized");

        // 添加到白名单
        whitelistedEnterprises[enterprise] = true;

        // 初始化企业碳积分账户
        carbonAccounts[enterprise] = CarbonAccount({currentBalance: 0, totalPurchased: 0, totalUsed: 0, isActive: true});

        _grantRole(VALIDATOR_ENTERPRISE, enterprise);
        emit EnterpriseInitialized(enterprise);
    }

    /**
     * @dev 企业使用碳积分
     * @param amount 使用数量
     */
    function useCarbonCredits(uint256 amount) external onlyRole(VALIDATOR_ENTERPRISE) {
        // 验证企业资格
        require(whitelistedEnterprises[msg.sender], "Enterprise not whitelisted");
        require(carbonAccounts[msg.sender].isActive, "Enterprise not active");

        CarbonAccount storage account = carbonAccounts[msg.sender];
        require(account.currentBalance >= amount, "Insufficient carbon credits");

        // 更新企业碳积分账户
        account.currentBalance -= amount;
        account.totalUsed += amount;

        // 销毁使用的碳积分
        _burn(msg.sender, amount);

        emit EnterpriseCarbonUsed(msg.sender, amount);
    }

    // ========== 碳积分查询接口 ==========

    /**
     * @dev 查询地址的碳积分余额
     * @param account 查询地址
     * @return 碳积分余额
     */
    function getCarbonBalance(address account) external view returns (uint256) {
        return balanceOf(account);
    }

    /**
     * @dev 查询运营商完整信息
     * @param operator 运营商地址
     * @return 运营商信息结构体
     */
    function getOperatorInfo(address operator) external view returns (Operator memory) {
        return operators[operator];
    }

    /**
     * @dev 查询企业碳积分账户信息
     * @param enterprise 企业地址
     * @return 企业碳积分账户信息
     */
    function getEnterpriseCarbonAccount(address enterprise) external view returns (CarbonAccount memory) {
        return carbonAccounts[enterprise];
    }

        /**
     * @dev 查询调度结果
     * @param taskId 任务ID
     * @return 调度结果结构体
     */
    function getDispatchResult(uint256 taskId) external view returns (DishpatchResult memory) {
        return dispatchResults[taskId];
    }
}
