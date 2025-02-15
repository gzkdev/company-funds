// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

contract CompanyFunds {
    address public owner;
    
    struct MonthlyBudget {
        uint256 amount;
        uint256 deadline;
        mapping(address => bool) hasSignedBudget;
        uint256 signatureCount;
        bool isExecuted;
        bool exists;
    }

    struct Expense {
        uint256 amount;
        address payable recipient;
        string description;
        uint256 monthlyBudgetId;
        bool isExecuted;
    }

    mapping(uint256 => MonthlyBudget) public monthlyBudgets;
    mapping(uint256 => Expense) public expenses;
    mapping(address => bool) public boardMembers;
    
    uint256 public constant REQUIRED_SIGNATURES = 20;
    uint256 public budgetCounter;
    uint256 public expenseCounter;
    uint256 public boardMemberCount;
    
    bool private locked;

    event BudgetCreated(uint256 indexed budgetId, uint256 amount, uint256 deadline);
    event BudgetSigned(uint256 indexed budgetId, address signer);
    event BudgetExecuted(uint256 indexed budgetId);
    event ExpenseCreated(uint256 indexed expenseId, uint256 amount, address recipient);
    event ExpenseExecuted(uint256 indexed expenseId, uint256 amount, address recipient);
    event BoardMemberAdded(address member);
    event BoardMemberRemoved(address member);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    modifier onlyBoardMember() {
        require(boardMembers[msg.sender], "Not a board member");
        _;
    }

    modifier noReentrant() {
        require(!locked, "Reentrant call");
        locked = true;
        _;
        locked = false;
    }

    constructor() {
        owner = msg.sender;
        boardMembers[msg.sender] = true;
        boardMemberCount = 1;
        emit BoardMemberAdded(msg.sender);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner is zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function addBoardMember(address _member) external onlyOwner {
        require(_member != address(0), "Invalid address");
        require(!boardMembers[_member], "Already a board member");
        require(boardMemberCount < REQUIRED_SIGNATURES, "Maximum board members reached");
        
        boardMembers[_member] = true;
        boardMemberCount++;
        emit BoardMemberAdded(_member);
    }

    function removeBoardMember(address _member) external onlyOwner {
        require(_member != owner, "Cannot remove owner");
        require(boardMembers[_member], "Not a board member");
        
        boardMembers[_member] = false;
        boardMemberCount--;
        emit BoardMemberRemoved(_member);
    }

    function createMonthlyBudget(uint256 _amount, uint256 _deadline) external onlyOwner {
        require(_deadline > block.timestamp, "Deadline must be in future");
        require(_amount > 0, "Amount must be greater than 0");

        budgetCounter++;
        MonthlyBudget storage budget = monthlyBudgets[budgetCounter];
        budget.amount = _amount;
        budget.deadline = _deadline;
        budget.signatureCount = 0;
        budget.isExecuted = false;
        budget.exists = true;

        emit BudgetCreated(budgetCounter, _amount, _deadline);
    }

    function signBudget(uint256 _budgetId) external onlyBoardMember {
        MonthlyBudget storage budget = monthlyBudgets[_budgetId];
        require(budget.exists, "Budget does not exist");
        require(!budget.isExecuted, "Budget already executed");
        require(block.timestamp <= budget.deadline, "Budget deadline passed");
        require(!budget.hasSignedBudget[msg.sender], "Already signed");

        budget.hasSignedBudget[msg.sender] = true;
        budget.signatureCount++;
        
        emit BudgetSigned(_budgetId, msg.sender);
    }

    function createExpense(
        uint256 _budgetId,
        uint256 _amount,
        address payable _recipient,
        string memory _description
    ) external onlyOwner {
        require(monthlyBudgets[_budgetId].exists, "Budget does not exist");
        require(_amount > 0, "Amount must be greater than 0");
        require(_recipient != address(0), "Invalid recipient");

        expenseCounter++;
        expenses[expenseCounter] = Expense({
            amount: _amount,
            recipient: _recipient,
            description: _description,
            monthlyBudgetId: _budgetId,
            isExecuted: false
        });

        emit ExpenseCreated(expenseCounter, _amount, _recipient);
    }

    function executeExpense(uint256 _expenseId) external onlyOwner noReentrant {
        Expense storage expense = expenses[_expenseId];
        MonthlyBudget storage budget = monthlyBudgets[expense.monthlyBudgetId];
        
        require(!expense.isExecuted, "Expense already executed");
        require(budget.signatureCount >= REQUIRED_SIGNATURES, "Insufficient signatures");
        require(budget.exists && !budget.isExecuted, "Invalid budget state");
        require(address(this).balance >= expense.amount, "Insufficient balance");
        require(expense.amount <= budget.amount, "Expense exceeds budget");

        expense.isExecuted = true;
        budget.isExecuted = true;
        
        (bool success, ) = expense.recipient.call{value: expense.amount}("");
        require(success, "Transfer failed");
        
        emit ExpenseExecuted(_expenseId, expense.amount, expense.recipient);
        emit BudgetExecuted(expense.monthlyBudgetId);
    }

    function getBudgetSignatures(uint256 _budgetId) external view returns (uint256) {
        return monthlyBudgets[_budgetId].signatureCount;
    }

    function hasSigned(uint256 _budgetId, address _member) external view returns (bool) {
        return monthlyBudgets[_budgetId].hasSignedBudget[_member];
    }

    receive() external payable {}
}