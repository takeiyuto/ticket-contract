// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Tickets is ERC721, Ownable {
    string private constant _name = "Ticket NFT";

    constructor() ERC721(_name, "") {}

    uint256[] internal tokenPrices;
    PriceRecord[] public priceRecords;

    uint96 public constant INVALID_PRICE = type(uint96).max;

    struct PriceRecord {
        uint32 validTo;
        uint96 price;
    }

    function getCurrentPrice() public view returns (uint256) {
        return getPrice(block.number);
    }

    function getPrice(uint256 blockNumber) public view returns (uint256) {
        uint256 priceRecordCount = priceRecords.length;
        for (uint256 i = 0; i < priceRecordCount; i++) {
            PriceRecord memory priceRecord = priceRecords[i];

            if (blockNumber <= priceRecord.validTo) {
                return priceRecord.price;
            }
        }

        return INVALID_PRICE;
    }

    function _pushPrice(uint256 validTo, uint256 price) private {
        priceRecords.push(
            PriceRecord({
                validTo: uint32(validTo),
                price: price >= INVALID_PRICE ? INVALID_PRICE : uint96(price)
            })
        );
    }

    function setPrice(uint256 validTo, uint256 price) public onlyOwner {
        require(validTo > block.number, "Past price update rejected");

        uint96 lastPrice = INVALID_PRICE;
        PriceRecord memory priceRecord;
        uint256 i;
        for (i = priceRecords.length; i > 0; i--) {
            priceRecord = priceRecords[i - 1];

            if (priceRecord.validTo < validTo) {
                break;
            }

            lastPrice = priceRecord.price;
            priceRecords.pop();
        }

        if ((i == 0 || priceRecord.validTo < block.number) && lastPrice != price) {
            _pushPrice(block.number, lastPrice);
        }
        _pushPrice(validTo, price);
    }

    function totalPriceRecords() public view returns (uint256) {
        return priceRecords.length;
    }

    function isOnSale() public view returns (bool) {
        return getPrice(block.number) < INVALID_PRICE;
    }

    function purchase() public payable {
        require(isOnSale(), "Not on sale");
        require(balanceOf(_msgSender()) == 0, "Already purchased");

        uint256 currentPrice = getCurrentPrice();
        require(msg.value >= currentPrice, "Insufficient fund");

        tokenPrices.push(currentPrice);
        uint256 tokenId = tokenPrices.length;
        _safeMint(_msgSender(), tokenId);
    }

    function refund(uint256 tokenId) public {
        require(isOnSale(), "Refund available only while on sale");
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Caller is not owner nor approved"
        );

        uint256 tokenPrice = tokenPrices[tokenId - 1];
        delete tokenPrices[tokenId - 1];

        uint256 refundAmount = tokenPrice >> 1;
        address payable recipient = payable(ownerOf(tokenId));

        _burn(tokenId);
        recipient.transfer(refundAmount);
    }

    function _beforeTokenTransfer(address from, address to, uint256, uint256) internal view override {
        require(!isOnSale() || from == address(0) || to == address(0));
    }

    function firstTokenOfOwner(address owner) public view returns (uint256 ret) {
        require(balanceOf(owner) > 0, "Not a token owner");

        uint256 count = tokenPrices.length;
        for (uint256 i = 0; i++ < count; ) {
            if (_exists(i) && ownerOf(i) == owner) {
                return i;
            }
        }

        assert(false);
        return 0;
    }

    function withdrawAll() public onlyOwner {
        require(
            !isOnSale(),
            "Admins can withdraw funds only after the sale is over."
        );

        payable(_msgSender()).transfer(address(this).balance);
    }
}
