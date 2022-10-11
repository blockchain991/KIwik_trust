
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./NFT.sol";

contract FactoryMintingContract {
    NFT[] public nftContractAddress;
    address nft;

    event mintingCreated(address _mintingContract);
    constructor(){
        deployMintingContract();
    }

    function deployMintingContract() public  {
        NFT nftContract = new NFT("KwikTrust", "KTX");

        nftContractAddress.push(nftContract);
        nft= address(nftContract);
        nft=address(nftContract);
        emit mintingCreated(address(nftContract));
    }

    function getAdrdress() external view returns (address) {
        return nft;
    }

    function getMetaCoins() external view returns (NFT[] memory) {
        return nftContractAddress;
    }
    //0xF27374C91BF602603AC5C9DaCC19BE431E3501cb
}