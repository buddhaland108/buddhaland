// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Buddhaland is Ownable, ERC721 {
    using Strings for uint256;
    using SafeERC20 for IERC20;

    struct BuyRecord {
        address buyer;
        uint128 price;
        uint32 buyTime;
    }

    string public baseURI;
    uint16 public totalNum = 1000;
    uint16 public mintedNum;
    uint128 public price;
    address public priceToken;
    bytes32 public merkleRoot;
    address public vault;

    mapping(uint16 => BuyRecord) public buyRecords;
    mapping(address => bool) public developers;


    event ChangeVault(address oldVault, address newVault);
    event ChangePrice(uint128 oldPrice, uint128 newPrice);
    event UpdateDeveloper(address dev, bool valid);
    event UpdateSales(bytes32 oldMerkleRoot, bytes32 newMerkleRoot);
    event Mint(address indexed user, uint16 indexed tokenId, uint128 price);

    constructor(string memory _name, string memory _symbol, address _owner, address _vault, uint128 _price, address _priceToken) ERC721(_name, _symbol) Ownable(_owner){
        vault = _vault;
        price = _price;
        priceToken = _priceToken;
    }

    modifier onlyOwnerOrDev() {
        require(msg.sender == owner() || developers[msg.sender] == true, 'OnlyOwnerOrDev');
        _;
    }

    function setDeveloper(address dev, bool valid) external onlyOwner  {
        developers[dev] = valid;
        emit UpdateDeveloper(dev, valid);
    }

    function setBaseURI(string memory _baseURI) external onlyOwnerOrDev {
        baseURI = _baseURI;
    }

    function setVault(address _vault) external onlyOwner {
        address oldVault = vault;
        vault = _vault;
        emit ChangeVault(oldVault, _vault);
    }

    function setPrice(uint128 _price) external onlyOwnerOrDev {
        emit ChangePrice(price, _price);
        price = _price;
    }

    function tokenURI(uint tokenId) public view override returns (string memory) {
        string memory _baseURI = baseURI;
        return bytes(_baseURI).length > 0 ? string.concat(_baseURI, tokenId.toString()) : "";
    }

    function setSales(bytes32 _merkleRoot) external onlyOwnerOrDev {
        emit UpdateSales(merkleRoot, _merkleRoot);
        merkleRoot = _merkleRoot;
    }

    function multiMint(uint16[] memory tokenIds, address[] memory _users, uint32[] memory deadline, bytes32[][] memory proof) external {
        for (uint8 i=0; i<tokenIds.length; i++) {
            mint(tokenIds[i], _users[i], deadline[i], proof[i]);
        }
    }

    function mint(uint16 tokenId, address _user, uint32 deadline, bytes32[] memory proof) public {
        require(_verifyProof(tokenId, _user, deadline, proof), 'VerifyFail');
        require(_ownerOf(tokenId) == address(0), 'NFTMinted');
        require(block.timestamp <= deadline, 'Expired');

        IERC20(priceToken).safeTransferFrom(msg.sender, vault, price);

        mintedNum++;
        require(mintedNum <= totalNum, "SoldOut");
        _mint(_user, tokenId);

        buyRecords[tokenId] = BuyRecord(_user, price, uint32(block.timestamp));

        emit Mint(_user, tokenId, price);
    }

    function getNftBuyRecords(uint16 indexStart,uint16 indexLength) public view returns (uint16, BuyRecord[] memory) {
        BuyRecord[] memory res = new BuyRecord[](indexLength);
        for (uint16 i = indexStart; i < indexStart+indexLength ; i++) {
            BuyRecord memory currentNftBuyInfo = buyRecords[i];
            res[i-indexStart] = currentNftBuyInfo;
        }
        return (mintedNum,res);
    }

    function _verifyProof(
        uint16 tokenId,
        address user,
        uint32 deadline,
        bytes32[] memory proof
    ) internal view returns (bool) {
        require(merkleRoot != bytes32(0), 'SetFirst');
        bytes32 leaf = keccak256(abi.encode(tokenId, user, deadline));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

}
