// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract Marketplace is ReentrancyGuard, AccessControl {
    // Marketplace declarations
    // AccessControl
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    // token listed NFT in marketplace
    uint256 public itemCount;

    // struct
    struct Item {
        uint256 tokenId;
        IERC20 token;
        uint256 price;
        address tokenAddress;
        address payable seller;
    }

    mapping(uint256 => mapping(address => Item)) public items;

    // events
    event offeredSingle(
        uint256 itemId,
        uint256 tokenId,
        address tokenAddress,
        uint256 price,
        address indexed seller
    );

    event offeredMultiple(
        uint256 itemId,
        uint256[] tokenId,
        address tokenAddress,
        uint256 price,
        address indexed seller
    );

    event Bought(
        uint256 itemId,
        uint256 tokenId,
        address tokenAddress,
        uint256 price,
        address indexed seller,
        address indexed buyer
    );

    event transferSingleNft(
        address _to,
        uint256 _tokenId,
        address tokenAddress
    );
    event transferMultipleNft(
        address _to,
        uint256[] _tokenId,
        address tokenAddress
    );

    // bidding declarations
    uint256 public biddingItems;

    struct AuctionItem {
        uint256 tokenId;
        address tokenAddress;
        IERC20 token;
        address payable owner;
        uint256 askingPrice;
        address payable seller;
        address highestBidder;
        uint256 endTime;
    }

    mapping(uint256 => mapping(address => AuctionItem)) public itemsForAuction;
    mapping(address => mapping(uint256 => bool)) public activeItems;

    event itemAdded(
        uint256 id,
        uint256 tokenId,
        address tokenAddress,
        uint256 askingPrice
    );
    event bidClaimed(uint256 id, address buyer, uint256 askingPrice);
    event highBidder(address _highestBidder, uint256 _price);

    // modifers
    modifier accessRole() {
        require(hasRole(TRANSFER_ROLE, msg.sender), "0x00");
        _;
    }

    // constructor
    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev list NFT in marketplace
     * @param _tokenId token id to be listed
     * @param _price listing price of token
     */

    function makeItem(
        IERC20 _token,
        uint256 _tokenId,
        address _tokenAddress,
        uint256 _price
    ) external nonReentrant {
        require(_price > 0, "0x01");
        // increment item count
        itemCount++;
        // transfer nft
        IERC721(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokenId
        );
        // add new item to items mapping
        items[_tokenId][_tokenAddress] = Item(
            _tokenId,
            _token,
            _price,
            _tokenAddress,
            payable(msg.sender)
        );
        // emit Offered event
        emit offeredSingle(
            itemCount,
            _tokenId,
            _tokenAddress,
            _price,
            msg.sender
        );
    }

    /**
     * @dev list multiple NFTs in marketplace
     * @param _nft minting contract address
     * @param _tokenId array of token ids to be listed
     * @param _price listing price of token
     */

    function makeItemBulk(
        IERC721 _nft,
        IERC20 _token,
        uint256[] memory _tokenId,
        address _tokenAddress,
        uint256 _price
    ) external nonReentrant {
        require(_price > 0, "Price must be greater than zero");
        for (uint256 i = 0; i < _tokenId.length; i++) {
            // increment item count
            itemCount++;
            // transfer nft
            _nft.transferFrom(msg.sender, address(this), _tokenId[i]);

            // add new item to items mapping
            items[_tokenId[i]][_tokenAddress] = Item(
                _tokenId[i],
                _token,
                _price,
                _tokenAddress,
                payable(msg.sender)
            );
        }
        emit offeredMultiple(
            itemCount,
            _tokenId,
            _tokenAddress,
            _price,
            msg.sender
        );
    }

    /**
     * @dev purchase NFT from marketplace
     * @param _itemId NFT token id
     * @param _tokenAddress NFT Contract Adress
     */

    function purchaseItem(uint256 _itemId, address _tokenAddress)
        external
        payable
        nonReentrant
    {
        uint256 _totalPrice = items[_itemId][_tokenAddress].price;
        Item memory item = items[_itemId][_tokenAddress];
        require(_itemId > 0 && _itemId <= itemCount, "item doesn't exist");
        require(
            msg.value >= _totalPrice,
            "not enough ether to cover item price and market fee"
        );

        if (address(item.token) != address(0)) {
            item.token.transferFrom(msg.sender, item.seller, item.price);
        } else {
            item.seller.transfer(item.price);
        }
        // transfer nft to buyer
        IERC721(_tokenAddress).transferFrom(
            address(this),
            msg.sender,
            item.tokenId
        );

        // decrement item count
        itemCount--;

        // delete item from marketplace
        delete items[_itemId][_tokenAddress];
        // emit Bought event
        emit Bought(
            _itemId,
            item.tokenId,
            _tokenAddress,
            item.price,
            item.seller,
            msg.sender
        );
    }

    /**
     * @dev transfer multiple NFTs
     * @param _to reciever's address
     * @param _tokenIDs token ids to be sent
     */

    function transferNftBunch(
        address _to,
        uint256[] memory _tokenIDs,
        address _tokenAddress
    ) public accessRole {
        require(_tokenIDs.length < 150, "0x01");
        for (uint256 i = 0; i < _tokenIDs.length; i++) {
            //Item memory item = items[_tokenIDs[i]][_tokenAddress];
            IERC721(_tokenAddress).safeTransferFrom(
                address(this),
                _to,
                _tokenIDs[i]
            );
        }
        emit transferMultipleNft(_to, _tokenIDs, _tokenAddress);
    }

    /**
     * @dev transfer single NFT
     * @param _to reciever's address
     * @param _tokenID token ids to be sent
     */

    function transferNft(
        address _to,
        uint256 _tokenID,
        address _tokenAddress
    ) public accessRole {
        Item memory item = items[_tokenID][_tokenAddress];
        IERC721(item.tokenAddress).safeTransferFrom(
            address(this),
            _to,
            _tokenID
        );
        emit transferSingleNft(_to, _tokenID, _tokenAddress);
    }

    // bidding functions

    /**
     * @dev listing an item for bidding
     * @param _tokenId Token Id of NFT
     * @param _tokenAddress Contract address of NFT
     * @param _askingPrice mininum price of bidding
     * @param _time ending time of an auction
     * @param _token ERC20 token address
     */

    function addItemToBid(
        uint256 _tokenId,
        address _tokenAddress,
        uint256 _askingPrice,
        uint256 _time,
        IERC20 _token
    ) external nonReentrant returns (uint256) {
        require(_askingPrice > 0, "Price must be greater than zero");
        // require(block.timestamp > _time, "Time");

        itemsForAuction[_tokenId][_tokenAddress] = AuctionItem(
            _tokenId,
            _tokenAddress,
            _token,
            payable(msg.sender),
            _askingPrice,
            payable(address(this)),
            address(0),
            _time
        );
        assert(itemsForAuction[_tokenId][_tokenAddress].tokenId == _tokenId);
        activeItems[_tokenAddress][_tokenId] = true;
        IERC721(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _tokenId
        );
        biddingItems++;
        emit itemAdded(_tokenId, _tokenId, _tokenAddress, _askingPrice);
        return (_tokenId);
    }

    /***
     * @dev placing bid for token 
     * @param _tokenId Token Id of NFT
     * @param _tokenAddress Contract address of NFT
     * @param _amount  Amount enter by user
     */

    function bidToken(
        uint256 _tokenId,
        address _tokenAddress,
        uint256 _amount
    ) public payable {
        // require(address(itemsForAuction[_tokenId][_tokenAddress].token) != address(0), "m");
        // require(block.timestamp < itemsForAuction[_tokenId][_tokenAddress].endTime, "Auction has been ended");
        require(
            itemsForAuction[_tokenId][_tokenAddress].askingPrice < _amount,
            "Amount must be greater then previous bid"
        );
        //require(itemsForAuction[_tokenId][_tokenAddress].highestBidder == itemsForAuction[_tokenId][_tokenAddress].owner, "0x");
        itemsForAuction[_tokenId][_tokenAddress].token.transferFrom(
            _msgSender(),
            address(this),
            _amount
        );
        if (
            itemsForAuction[_tokenId][_tokenAddress].highestBidder != address(0)
        ) {
            itemsForAuction[_tokenId][_tokenAddress].token.transfer(
                itemsForAuction[_tokenId][_tokenAddress].highestBidder,
                itemsForAuction[_tokenId][_tokenAddress].askingPrice
            );
        }

        itemsForAuction[_tokenId][_tokenAddress].highestBidder = msg.sender;
        itemsForAuction[_tokenId][_tokenAddress].askingPrice = _amount;
        emit highBidder(msg.sender, _amount);
    }

    /**
     * @dev placing bid for nft
     * @param _tokenId Token Id of NFT
     * @param _tokenAddress Contract address of NFT
     */

    function bidNft(uint256 _tokenId, address _tokenAddress) public payable {
        require(
            address(itemsForAuction[_tokenId][_tokenAddress].token) ==
                address(0),
            "m"
        );
        require(
            block.timestamp > itemsForAuction[_tokenId][_tokenAddress].endTime,
            "Auction has been ended"
        );
        require(
            itemsForAuction[_tokenId][_tokenAddress].askingPrice < msg.value,
            "Amount must be greater then previous bid"
        );
        if (
            itemsForAuction[_tokenId][_tokenAddress].highestBidder !=
            itemsForAuction[_tokenId][_tokenAddress].owner
        ) {
            payable(itemsForAuction[_tokenId][_tokenAddress].highestBidder)
                .transfer(itemsForAuction[_tokenId][_tokenAddress].askingPrice);
        }
        itemsForAuction[_tokenId][_tokenAddress].highestBidder = msg.sender;
        itemsForAuction[_tokenId][_tokenAddress].askingPrice = msg.value;
        emit highBidder(msg.sender, msg.value);
    }

    /**
     * @dev claim function for highest bidder to claim NFT for token
     * @param _tokenId Token Id of NFT
     * @param _tokenAddress Contract address of NFT
     */
    function claimNft(uint256 _tokenId, address _tokenAddress)
        external
        payable
        nonReentrant
    {
        require(
            block.timestamp > itemsForAuction[_tokenId][_tokenAddress].endTime,
            "Auction is not completed yet!"
        );
        require(
            _msgSender() ==
                itemsForAuction[_tokenId][_tokenAddress].highestBidder ||
                _msgSender() == itemsForAuction[_tokenId][_tokenAddress].owner,
            "You are not the owner or Higgest Bidder"
        );
        activeItems[itemsForAuction[_tokenId][_tokenAddress].tokenAddress][
            itemsForAuction[_tokenId][_tokenAddress].tokenId
        ] = false;
        IERC721(itemsForAuction[_tokenId][_tokenAddress].tokenAddress)
            .transferFrom(
                address(this),
                itemsForAuction[_tokenId][_tokenAddress].highestBidder,
                itemsForAuction[_tokenId][_tokenAddress].tokenId
            );
        itemsForAuction[_tokenId][_tokenAddress].owner.transfer(
            itemsForAuction[_tokenId][_tokenAddress].askingPrice
        );
        delete itemsForAuction[_tokenId][_tokenAddress];
        biddingItems--;
        emit bidClaimed(
            _tokenId,
            msg.sender,
            itemsForAuction[_tokenId][_tokenAddress].askingPrice
        );
    }

    /**
     * @dev claim function for highest bidder to claim NFT For Nft
     * @param _tokenId Token Id of NFT
     * @param _tokenAddress Contract address of NFT
     */

    function claimToken(uint256 _tokenId, address _tokenAddress)
        external
        payable
        nonReentrant
    {
        //require(block.timestamp >itemsForAuction[_tokenId][_tokenAddress].endTime, "Auction is not completed yet!");
        require(
            _msgSender() ==
                itemsForAuction[_tokenId][_tokenAddress].highestBidder ||
                _msgSender() == itemsForAuction[_tokenId][_tokenAddress].owner,
            "You are not the owner or Higgest Bidder"
        );
        activeItems[itemsForAuction[_tokenId][_tokenAddress].tokenAddress][
            itemsForAuction[_tokenId][_tokenAddress].tokenId
        ] = false;
        IERC721(itemsForAuction[_tokenId][_tokenAddress].tokenAddress)
            .transferFrom(
                address(this),
                itemsForAuction[_tokenId][_tokenAddress].highestBidder,
                itemsForAuction[_tokenId][_tokenAddress].tokenId
            );
        itemsForAuction[_tokenId][_tokenAddress].token.transfer(
            itemsForAuction[_tokenId][_tokenAddress].owner,
            itemsForAuction[_tokenId][_tokenAddress].askingPrice
        );
        delete itemsForAuction[_tokenId][_tokenAddress];
        biddingItems--;
        emit bidClaimed(
            _tokenId,
            msg.sender,
            itemsForAuction[_tokenId][_tokenAddress].askingPrice
        );
    }
}
