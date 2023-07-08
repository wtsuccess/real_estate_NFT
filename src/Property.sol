// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'openzeppelin-contracts/contracts/token/ERC721/ERC721.sol';
import 'openzeppelin-contracts/contracts/security/ReentrancyGuard.sol';

contract Property is ERC721, ReentrancyGuard {
  address public owner;
  string baseUri;
  uint256 tokenId = 0;
  uint256 updateVariantFee = 0.00001 ether;

  struct LandDetails {
    uint256 ULPIN;
    uint256 price;
    uint256 tokenId;
    address owner;
    bytes32 key;
  }

  mapping(address => LandDetails) addressToLand;
  mapping(uint256 => LandDetails) idToLand;
  mapping(bytes32 => bool) listed;

  LandDetails[] public allLands;

  event LandListed(address owner, uint256 price, uint256 ULPIN);
  event LandBought(address newOwner, uint256 tokenId, uint256 price);
  event updatedPrice(address by, uint256 tokenId, uint256 newPrice);

  constructor(string memory _baseUri) ERC721('ASSETS', 'AST') {
    owner = msg.sender;
    baseUri = _baseUri;
  }

  function generateKey(uint256 _ULPIN) private view returns (bytes32) {
    uint256 nonce = 1;
    bytes32 key = keccak256(abi.encodePacked(_ULPIN, block.timestamp, nonce));
    nonce++;
    return key;
  }

  function listLandsToMarketplace(uint256 _ULPIN, uint256 _price) public payable onlyEOA {
    tokenId++;
    bytes32 key = generateKey(_ULPIN);
    LandDetails memory landDetails = LandDetails(_ULPIN, _price, tokenId, msg.sender, key);
    listed[key] = true;
    _safeMint(msg.sender, tokenId);
    safeTransferFrom(msg.sender, address(this), tokenId, '');
    addressToLand[msg.sender] = landDetails;
    idToLand[tokenId] = landDetails;
    allLands.push(landDetails);
    emit LandListed(msg.sender, _price, _ULPIN);
  }

  function buy(uint256 _tokenId) public payable onlyEOA nonReentrant {
    require(msg.sender != address(0), 'msg.sender is not valid address!');
    require(msg.value == idToLand[_tokenId].price);
    (bool sent, ) = idToLand[_tokenId].owner.call{value: msg.value}('');
    require(sent, 'Failed to send ether!');
    safeTransferFrom(address(this), msg.sender, _tokenId);
    delete listed[idToLand[_tokenId].key]; // deleting the respective key for this property because new key will be generated for new owner
    delete addressToLand[idToLand[_tokenId].owner];
    addressToLand[msg.sender] = idToLand[_tokenId];
    idToLand[_tokenId].owner = msg.sender; // new owner assigned
    uint256 ULPIN = idToLand[_tokenId].ULPIN;
    bytes32 key = generateKey(ULPIN); // generating new key for new owner
    idToLand[_tokenId].key = key; // new key assigned
    for (uint256 i = 0; i < allLands.length; i++) {
      if (allLands[i].tokenId == _tokenId) {
        allLands[i].owner = msg.sender;
        allLands[i].key = key;
      }
    }
    listed[key] = true; // new key is listed
    emit LandBought(msg.sender, _tokenId, msg.value);
  }

  function getYourKey(uint256 _tokenId) public view onlyEOA returns (bytes32) {
    require(msg.sender == idToLand[_tokenId].owner, 'Only owners of a property can see the unique key');
    return idToLand[_tokenId].key;
  }

  function updatePropertyPrice(uint256 _tokenId, uint256 _newPrice) public payable onlyEOA {
    require(msg.value == updateVariantFee, 'Please pay enough ether!');
    require(msg.sender == idToLand[_tokenId].owner, 'Only owner can update price.');
    idToLand[_tokenId].price = _newPrice;
    emit updatedPrice(msg.sender, _tokenId, _newPrice);
  }

  function getAllLandDetails() public view onlyEOA returns (LandDetails[] memory allDetails) {
    for (uint256 i = 0; i < allLands.length; i++) {
      allDetails[i] = allLands[i];
    }
    return allDetails;
  }

  function getMyLands() public view onlyEOA returns (LandDetails[] memory myAllDetails) {
    for (uint256 i = 0; i < allLands.length; i++) {
      if (allLands[i].owner == msg.sender) {
        myAllDetails[i] = allLands[i];
      }
    }
    return myAllDetails;
  }

  function withdrawETH() public nonReentrant {
    require(msg.sender == owner, 'Should only be called by owner');
    (bool sent, ) = owner.call{value: address(this).balance}('');
    require(sent, 'ETH transfer failed!');
  }

  modifier onlyEOA() {
    require(msg.sender.code.length != 0, "This function can't be called by any contract");
    _;
  }

  function _baseURI() internal view override returns (string memory) {
        return baseUri;
    }
}

// https://sepolia.etherscan.io/address/0x78fee11ce690178bb4875135b2e1c00342a65592