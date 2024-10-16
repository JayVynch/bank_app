pragma solidity >=0.4.22 <=0.8.17;

contract BankAccount
{
    event Deposit(
        address indexed user, 
        uint indexed accountId, 
        uint amount, 
        uint timestamp
    );

    event WithdrawalRequested(
        address indexed user, 
        uint indexed accountId, 
        uint withdrawalId, 
        uint amount, 
        uint timestamp
    );

    event Withdraw(
        uint withdrawalId,
        uint timestamp
    );

    event AccountCreated(
        address[] owners,
        uint indexed ids,
        uint timestamp
    );

    struct WithdrawRequest{
        address user;
        uint amount;
        uint approvals;
        mapping(address => bool) ownersApproved;
        bool approved;
    }

    struct Account{
        address[] owners;
        uint balance;
        mapping(uint => WithdrawRequest) withdrawRequests;
    }

    mapping(uint => Account) accounts;
    mapping(address => uint[]) userAccounts;

    uint nextAccountId;
    uint nextWithdrawalId;

    modifier AccountOwner(uint accountId)
    {
        bool isOwner;
        for (uint idx; idx < accounts[accountId].owners.length; idx++) {
            if(accounts[accountId].owners[idx] == msg.sender){
                isOwner = true;
                break;
            }
        }

        require(isOwner," You are not an owner of the account");
        _;
    }

    modifier validOwner(address[] memory owners)
    {
        require(owners.length + 1 <= 4,"Maximum of 4 users per account");

        for (uint i ; i < owners.length; i++) {
            if(owners[i] == msg.sender){
                revert("no duplicate owners");
            }

            for (uint j = i + 1; j < owners.length; j++) {
                if(owners[i] == owners[j]){
                    revert("no duplicate owners");
                }
            }
        }
        _;
    }

    modifier sufficientBalance(uint accountId, uint amount)
    {
        require(accounts[accountId].balance >= amount,"You do not have sufficient balance");
        _;
    }

    modifier canApprove(uint256 accountId, uint256 withdrawId)
    {
        require(!accounts[accountId].withdrawRequests[withdrawId].approved,"this request is already approved");

        require(
            accounts[accountId].withdrawRequests[withdrawId].user != msg.sender,"you cannot approve this request"
        );

        require(
            accounts[accountId].withdrawRequests[withdrawId].user != address(0),"you cannot approve this request"
        );

        require(
            !accounts[accountId].withdrawRequests[withdrawId].ownersApproved[msg.sender],"you have already approved this request"
        );

        _;
    }

    modifier canWithdraw(uint accountId, uint withdrawId)
    {
        require(accounts[accountId].withdrawRequests[withdrawId].user == msg.sender,"You do not own this account");

        require(accounts[accountId].withdrawRequests[withdrawId].approved, "This request is not approved");
        _;
    }

    function deposit(uint accountId) external payable AccountOwner(accountId)
    {
        accounts[accountId].balance += msg.value;
    }

    function createAccount(address[] calldata otherOwners) external validOwner(otherOwners)
    {
        address[] memory owners = new address[](otherOwners.length + 1);
        owners[otherOwners.length] = msg.sender;

        uint id = nextAccountId;

        //loop through the owners of accounts and check if each user has exceeded a max number
        // of account else we will not allow them to create an account
        for (uint idx; idx < owners.length; idx++) {
            //copy otherowners into the newly created owners address
            if(idx < owners.length - 1){
                owners[idx] = otherOwners[idx];
            }

            //check if owner has more than 3 max accounts
            if(userAccounts[owners[idx]].length > 2){
                revert("each user can have a max of 3 accounts");
            }

            userAccounts[owners[idx]].push(id);

            accounts[id].owners = owners;
            nextAccountId++;
            emit AccountCreated(owners, id, block.timestamp);
        }
    }

    function requestWithdrawl(uint accountId, uint amount) external AccountOwner(accountId) sufficientBalance(accountId, amount)
    {
        uint256 id = nextWithdrawalId;

        WithdrawRequest storage request = accounts[accountId].withdrawRequests[id];

        request.user = msg.sender;
        request.amount = amount;
        nextWithdrawalId++;

        emit WithdrawalRequested(msg.sender, accountId, id, amount, block.timestamp);
    }

    function approveWithdrawl(uint accountId, uint withdrawId) external AccountOwner(accountId) canApprove(accountId, withdrawId)
    {
        WithdrawRequest storage request = accounts[accountId].withdrawRequests[withdrawId];
        request.approvals++;
        request.ownersApproved[msg.sender] = true;

        if(request.approvals == accounts[accountId].owners.length - 1){
            request.approved = true;
        }
    }

    function withdraw(uint accountId, uint withdrawId) external canWithdraw(accountId, withdrawId)
    {
        uint amount = accounts[accountId].withdrawRequests[withdrawId].amount;

        require(accounts[accountId].balance >= amount,"Insuffucient Balance" );

        accounts[accountId].balance -= amount;
        delete(accounts[accountId].withdrawRequests[withdrawId]);

        (bool sent,) = payable(msg.sender).call{value: amount}("");
        require(sent);

        emit Withdraw(withdrawId, block.timestamp);
    }

    function getBalance(uint256 accountId) public view returns(uint256)
    {
        return accounts[accountId].balance;
    }

    function getOwners(uint256 accountId) public view returns(address[] memory)
    {
        return accounts[accountId].owners;
    }

    function getApprovals(uint256 accountId, uint256 withdrawId) public view returns(uint256)
    {
        return accounts[accountId].withdrawRequests[withdrawId].approvals;
    }

    function getAccounts() public view returns(uint256[] memory)
    {
        return userAccounts[msg.sender];
    }
}