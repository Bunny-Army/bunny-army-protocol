//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";

import "./interface/IJswapRouter.sol";

interface IBreedScience {
    //@dev random % based < hitRate ? 1 : 0
    //@return gender 0:female 1:male
    function breeedGender(uint256 based, uint256 hitRate) external view returns (uint256 hit);
}

contract BunnyArmy is  ERC721EnumerableUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;

    address public BAC;
    address public USDT;
    address public jfRouter;
    address public adoptFeeTo;
    address public breefFeeTo;

    IBreedScience public breedScience;
    

    uint256 public pricePerBunny;
    uint256 public adoptMaleCount;
    uint256 public adoptFemaleCount;

    uint256 public priceBaseBreedBunny;
    uint256 public breedStartAt; //timestamp
    uint256 public breedFemaleRate;  // 100 based

    uint256 public totalSaledBunny; 
    uint256 public totalSaledValue; 

    uint256 public constant MAX_MALE_COUNT = 7000;
    uint256 public constant MAX_FEMALE_COUNT = 3000;

    mapping(uint256 => uint256) bunnyGender;
    mapping(uint256 => uint256) bunnyBreedCount;

    mapping(uint256 => uint256) bunnyFather;
    mapping(uint256 => uint256) bunnyMother;


    mapping(uint256 => uint256) bunnyPrice;
    EnumerableSet.UintSet private bunnyOnSale;

    string private baseURI;


    event BunnyAdopt(uint256 indexed _tokenId, address indexed _owner);
    event BunnyBreed(uint256 indexed _tokenId, address _owner);
    event BunnySale(uint256 indexed _tokenId, address indexed _owner, uint256 _price);
    event BunnySaleCancle(uint256 indexed _tokenId);
    event BunnySaleSuc(uint256 indexed _tokenId, address indexed _buyer);

    function initialize(address _carAddr, address _usdtAddr )  initializer public {

        __Ownable_init();
        __ERC721_init("Bunny Army", "BUNNY");

        BAC  = _carAddr;
        USDT = _usdtAddr;

        breedFemaleRate = 60;
    }

    /**
     * @notice adropt bunnry
     * @dev approve USDT before call `adoptBunny`
     */
    function adoptBunny() external returns (uint256 tokenId) {
        
        require(pricePerBunny > 0,  "BurnnyLegion: price not set");
        require(adoptFeeTo != address(0),  "BurnnyLegion: adoptFeeTo not set");
        
        uint256 _gender = geneAdoptGander();
        if(_gender == 1) {
            require(adoptMaleCount < MAX_MALE_COUNT, "BurnnyLegion: no left A");
            adoptMaleCount += 1;
        } else {
            require(adoptFemaleCount < MAX_FEMALE_COUNT, "BurnnyLegion: no left B");
            adoptFemaleCount += 1;
        }

        tokenId = totalSupply();
        bunnyGender[tokenId] = _gender;
        //mint bunny
        _mint(msg.sender, tokenId);

        IERC20(USDT).safeTransferFrom(msg.sender, adoptFeeTo, pricePerBunny);
        emit BunnyAdopt(tokenId, msg.sender);
    }

    /***
     * @notice breed Bunny with mathorBunny & FatherToken
     * @param _matronId Mather Bunny ID
     * @param _sireId   Father Bunny ID
     */
    function breedBunny(uint256 _matronId, uint256 _sireId) external returns (uint256 tokenId) {
        require(block.timestamp >= breedStartAt, "BunnyArmy: breed not start");
        require(bunnyGender[_matronId] == 0, "BunnyArmy: mather must be female");
        require(bunnyGender[_sireId] == 1, "BunnyArmy: father must be male");

        require(ownerOf(_matronId) == msg.sender, "BunnyArmy:  Matron not owner");
        require(ownerOf(_sireId) == msg.sender, "BunnyArmy:  Sire not owner");

        require(bunnyMother[_sireId] != _matronId || _matronId==0, "Bunny: can not breed with mother");
        require(bunnyFather[_matronId] != _sireId || _sireId==0, "Bunny: can not breed with father");

        uint256 breedCount =  bunnyBreedCount[_matronId];
        uint256 breedFee = priceBaseBreedBunny.mul(breedCount + 1);

        tokenId = mintWithGender( geneBreedGander() , msg.sender);
        bunnyBreedCount[_matronId] = breedCount + 1;

        bunnyMother[tokenId] = _matronId;
        bunnyFather[tokenId] = _sireId;

        IERC20(BAC).safeTransferFrom(msg.sender, BAC, breedFee);

        emit BunnyBreed(tokenId, msg.sender);
    }

    function geneBreedGander() private view returns(uint256 ) {
        require(breedFemaleRate > 0, "BunnyArmy: female rate cannot zero");
        require(breedFemaleRate < 100, "BunnyArmy: female rate cannot gt 100 based");

        return  breedScience.breeedGender(100, breedFemaleRate);
    }

    function geneAdoptGander() private view returns(uint256 ) {

        uint256 femaleLeft = MAX_FEMALE_COUNT - adoptFemaleCount;
        if(femaleLeft == 0) {
            return 1;
        }
        uint256 maleLeft = MAX_MALE_COUNT - adoptMaleCount;
        if(maleLeft == 0) {
            return 0;
        }
        return  breedScience.breeedGender(femaleLeft+maleLeft, femaleLeft);
    }
    /**
     * @notice sale Bunny in expect price
     * @param _tokenId  BunnyID
     * @param _price in `BAC` token
     */
    function saleBunny(uint256 _tokenId, uint256 _price) external {
        require(ownerOf(_tokenId) == msg.sender, "BunnyArmy: not owner");
        require(!bunnyOnSale.contains(_tokenId), "BunnyArmy: bunny is on sale");

        bunnyOnSale.add(_tokenId);
        bunnyPrice[_tokenId] = _price;

        emit BunnySale(_tokenId, msg.sender, _price);
    }

    /**
     * @notice cancle sale Bunny 
     * @param _tokenId  BunnyID
     */
    function cancleSaleBunny(uint256 _tokenId) external {
        require(ownerOf(_tokenId) == msg.sender, "BunnyArmy: not owner");
        require(bunnyOnSale.contains(_tokenId), "BunnyArmy: bunny not on sale");

        bunnyOnSale.remove(_tokenId);
        delete bunnyPrice[_tokenId];

        emit BunnySaleCancle(_tokenId);
    }

    function buyBunny(uint256 _tokenId) external {
        require(bunnyOnSale.contains(_tokenId), "BunnyArmy: bunny not on sale");
        require(breefFeeTo != address(0), "BunnyArmy: breefFeeTo not set");
        
        uint256 price = bunnyPrice[_tokenId];
        // 10% fee to breefFeeTo
        uint256 fee = price.div(10);
        IERC20(BAC).safeTransferFrom(msg.sender, breefFeeTo, fee);
        // 90% to saller
        IERC20(BAC).safeTransferFrom(msg.sender, ownerOf(_tokenId), price.sub(fee));

        bunnyOnSale.remove(_tokenId);
        delete bunnyPrice[_tokenId];

        _transfer(ownerOf(_tokenId), msg.sender, _tokenId);     

        totalSaledBunny += 1;
        totalSaledValue += price;

        emit BunnySaleSuc(_tokenId, msg.sender);
    }
    /// ******* Setting Part *****
    function setBaseURI(string memory _uri) external onlyOwner {
        baseURI = _uri;
    }

    function setAdoptPrice(uint256 _price) external onlyOwner {
        pricePerBunny = _price;
    }

    function setBreedStartAt(uint256 _startAt) external onlyOwner {
        breedStartAt = _startAt;
    }

    function setBreedPrice(uint256 _breedPrice) external onlyOwner {
        priceBaseBreedBunny = _breedPrice;
    }


    function setAdoptFeeTo(address _feeTo) external onlyOwner {
        adoptFeeTo = _feeTo;
    }

    function setBreedFeeTo(address _feeTo) external onlyOwner {
        breefFeeTo = _feeTo;
    }

    function setBreedScience(address _breedScience) external onlyOwner {
        breedScience = IBreedScience(_breedScience);
    }

     function setBreedFemaleRate(uint256 _femaleRate) external onlyOwner {
        breedFemaleRate = _femaleRate;
    }

    /// ******* Setting Part END *****
    
 
    /// ******* View Part *****
    function mintWithGender(uint256 gender, address _owner) private returns (uint256 tokenId) {
        tokenId = totalSupply();
        bunnyGender[tokenId] = gender;
        _mint(_owner, tokenId);
    }

    function bunnyInfo(uint256 _tokenId) public view returns (uint256 tokenId,  address owner, uint256 gander, uint256 breedCount, bool onSale, uint256 price) {
        
        tokenId = _tokenId;
        owner = ownerOf(tokenId);
        gander = bunnyGender[tokenId];
        breedCount = bunnyBreedCount[tokenId];
        onSale = bunnyOnSale.contains(tokenId);
        price = bunnyPrice[tokenId];
    }

    function adoptedCount() external view returns (uint256 adopted, uint256 total) {
        return (adoptMaleCount + adoptFemaleCount, MAX_MALE_COUNT + MAX_FEMALE_COUNT );
    }

    function onSaleLength() external view returns (uint256) {
        return bunnyOnSale.length();
    }

    function onSaleInfoByIndex(uint256 _index) external view returns (uint256 tokenId,  address owner, uint256 gander, uint256 breedCount, bool onSale, uint256 price) {
        require(_index < bunnyOnSale.length(), "BunnyArmy: index out of bound");

        uint256 _tokenId = bunnyOnSale.at(_index);
        return bunnyInfo(_tokenId);
    }

    /// Utils Part

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    /// Override Part
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(!bunnyOnSale.contains(tokenId) , "BunnyArmy: cannot transfer bunny on sale");
        super._beforeTokenTransfer(from, to, tokenId);
    }

}