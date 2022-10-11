// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";

contract NFT is ERC721URIStorage, EIP712, AccessControl {
    // Roles
    bytes32 public constant VALIDATOR_ROLE = keccak256("VALIDATOR_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // Signing domains
    string private constant SIGNING_DOMAIN = "KwikTrust-Voucher";
    string private constant SIGNATURE_VERSION = "1";

    // variable declarations
    uint256 public tokenId = 0;

    struct NFTVoucher {
        string uri;
        uint256 price;
        bytes signature;
        IERC20 token;
        bool isnative;
    }

    // events
    event handleMint(address _minter, uint256 id);
    event handleLazyMint(
        address signer,
        address minter,
        string uri,
        uint256 tokenId
    );

    // modifier
    modifier minterRole() {
        require(hasRole(MINTER_ROLE, msg.sender), "0x00");
        _;
    }

    // constructor
    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    /**
     * @dev nft minting
     * @param _tokenURI NFT URI
     * @param marketplace NFT Marketplace contract address
     */

    function mint(string memory _tokenURI, address marketplace)
        external
        minterRole
    {
        tokenId++;
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, _tokenURI);
        setApprovalForAll(marketplace, true);
        emit handleMint(msg.sender, tokenId);
    }

    /**
     * @dev nft minting
     * @param _tokenURI NFT URI
     * @param marketplace NFT Marketplace contract address
     */

    function bulkMint(string[] memory _tokenURI, address marketplace)
        external
        minterRole
    {
        require(_tokenURI.length < 150, "0x01");
        for (uint256 i = 0; i < _tokenURI.length; i++) {
            tokenId++;
            _safeMint(msg.sender, (tokenId));
            _setTokenURI((tokenId), _tokenURI[i]);
            setApprovalForAll(marketplace, true);
        }
        emit handleMint(msg.sender, tokenId);
    }

    /**
     * @dev nft minting
     * @param signer Signer's Address
     * @param minter Buyer's address, in lazyminting buyer is actually a minter
     * @param voucher struct: containing data of NFT
     * @param marketplace NFT Marketplace contract address
     */

    function lazyMint(
        address payable signer,
        address minter,
        NFTVoucher calldata voucher,
        address marketplace
    ) public payable returns (uint256) {
        address verifyValidator = _verify(voucher);
        require(hasRole(VALIDATOR_ROLE, verifyValidator), "0x02");
        require(msg.value >= voucher.price, "0X03");
        tokenId++;
        _safeMint(signer, tokenId);
        _setTokenURI(tokenId, voucher.uri);
        _transfer(signer, minter, tokenId);
        if (voucher.isnative == true) {
            signer.transfer(voucher.price);
        } else {
            voucher.token.transferFrom(minter, signer, voucher.price);
        }
        setApprovalForAll(marketplace, true);
        emit handleLazyMint(signer, minter, voucher.uri, tokenId);
        return (tokenId);
    }

    /**
     * @dev _hash, creating KECCAK hash of voucher
     * @param voucher struct: containing data of NFT
     */

    function _hash(NFTVoucher calldata voucher)
        internal
        view
        returns (bytes32)
    {
        return
            _hashTypedDataV4(
                keccak256(
                    abi.encode(
                        keccak256("NFTVoucher(string uri,uint256 price)"),
                        keccak256(bytes(voucher.uri)),
                        voucher.price
                    )
                )
            );
    }

    /**
     * @dev _verify, returns the public key
     * @param voucher struct: containing data of NFT
     */

    function _verify(NFTVoucher calldata voucher)
        internal
        view
        returns (address)
    {
        bytes32 digest = _hash(voucher);
        return ECDSA.recover(digest, voucher.signature);
    }

    /**
     * @dev supportsInterface
     * @param interfaceId interface id in bytes
     */

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC721)
        returns (bool)
    {
        return
            ERC721.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }
}
