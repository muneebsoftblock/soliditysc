// SPDX-License-Identifier: MIT

// getPrice warning

//
pragma solidity 0.8.14;

// For Remix
// import "erc721a@3.3.0/contracts/ERC721A.sol";
// import "erc721a@3.3.0/contracts/extensions/ERC721AQueryable.sol";

// For Truffle
import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721AQueryable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";

contract LaziName is ERC721A("Lazi Name Service", "LNS"), Ownable, ERC721AQueryable, ERC2981 {
    mapping(string => bool) public isMinted;
    mapping(uint256 => string) public domainNameOf;
    mapping(bytes => bool) public _signatureUsed;

    uint256 public laziNamePrice = 0.016 * 1e18; // $5 / 0.016 BNB
    uint256 public laziNamePriceWL = 0.010 * 1e18; // $3 / 0.01 BNB
    uint256 public saleActiveTime = type(uint256).max;

    address public mintSigner = msg.sender;

    string laziNameImages;

    // LaziName Auto Approves Marketplaces
    mapping(address => bool) private allowed;
    mapping(address => uint256) private _lastTransferBlock;

    // these lines are called only once when the contract is deployed
    constructor() {
        autoApproveMarketplace(0xF849de01B080aDC3A814FaBE1E2087475cF2E354); // X2y2
        autoApproveMarketplace(0x4feE7B061C97C9c496b01DbcE9CDb10c02f0a0Be); // Rarible
        autoApproveMarketplace(0x1E0049783F008A0085193E00003D00cd54003c71); // OpenSea
        autoApproveMarketplace(0xDef1C0ded9bec7F1a1670819833240f027b25EfF); // Coinbase
        autoApproveMarketplace(0xf42aa99F011A1fA7CDA90E5E98b277E306BcA83e); // LooksRare
    }

    function registerName(string calldata _laziName, uint256 tokenId) internal {
        require(!isMinted[_laziName], "Nft Domain Already Minted");
        isMinted[_laziName] = true;
        domainNameOf[tokenId] = _laziName;
    }

    function set_mintSigner(address _mintSigner) public onlyOwner {
        mintSigner = _mintSigner;
    }

    // Airdrop LaziName
    function airdrop(address[] calldata _addresses, string[] calldata _laziNames) external onlyOwner {
        uint256 startId = totalSupply() + _startTokenId();
        for (uint256 i = 0; i < _laziNames.length; i++) {
            registerName(_laziNames[i], startId + i);
        }
        for (uint256 i = 0; i < _laziNames.length; i++) {
            _safeMint(_addresses[i], 1);
        }
    }

    function airdrop(address _address, string[] calldata _laziNames) external onlyOwner {
        uint256 startId = totalSupply() + _startTokenId();
        for (uint256 i = 0; i < _laziNames.length; i++) {
            registerName(_laziNames[i], startId + i);
        }

        _safeMint(_address, _laziNames.length);
    }

    function buyLaziNames(string[] calldata _laziNames) external payable saleActive(saleActiveTime) pricePaid(_laziNames.length) {
        require(_lastTransferBlock[msg.sender] != block.number, "Repeat transaction in the same block");
        _lastTransferBlock[msg.sender] = block.number;
        uint256 startId = totalSupply() + _startTokenId();
        for (uint256 i = 0; i < _laziNames.length; i++) {
            registerName(_laziNames[i], startId + i);
        }

        _safeMint(msg.sender, _laziNames.length);
    }

    function buyLaziNamesWhitelist(
        string[] calldata _laziNames,
        bytes32 _signedMessageHash,
        bytes memory _signature
    ) external payable saleActive(saleActiveTime) pricePaidWL(_laziNames.length) {
        require(_lastTransferBlock[msg.sender] != block.number, "Repeat transaction in the same block");
        _lastTransferBlock[msg.sender] = block.number;
        require(_signatureUsed[_signature] == false, "Signature is Already Used");

        require(_signature.length == 65, "Invalid signature length");
        address recoveredMintSigner = verifySignature(_signedMessageHash, _signature);
        require(recoveredMintSigner == mintSigner, "Invalid signature");
        _signatureUsed[_signature] = true;

        uint256 startId = totalSupply() + _startTokenId();
        for (uint256 i = 0; i < _laziNames.length; i++) {
            registerName(_laziNames[i], startId + i);
        }

        _safeMint(msg.sender, _laziNames.length);
    }

    function messageHash(string memory _message) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _message));
    }

    function getEthSignedMessageHash(bytes32 _messageHash) public pure returns (bytes32) {
        /*
        Signature is produced by signing a keccak256 hash with the following format:
        "\x19Ethereum Signed Message\n" + len(msg) + msg
        */
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", _messageHash));
    }

    // verifySignature helper function
    function verifySignature(bytes32 _signedMessageHash, bytes memory _signature) public pure returns (address) {
        bytes32 r;
        bytes32 s;
        uint8 v;

        // Check the signature length
        require(_signature.length == 65, "Invalid signature length");

        // Divide the signature into its three components
        assembly {
            r := mload(add(_signature, 32))
            s := mload(add(_signature, 64))
            v := and(mload(add(_signature, 65)), 255)
        }

        // Ensure the validity of v
        // Ensure the validity of v
        if (v < 27) {
            v += 27;
        }
        require(v == 27 || v == 28, "Invalid signature v value");

        // Recover the signer's address
        address signer = ecrecover(_signedMessageHash, v, r, s);
        require(signer != address(0), "Invalid signature");

        return signer;
    }

    // onlyOwner functions
    function withdraw() external onlyOwner {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }

    function set_laziNamePrice(uint256 _laziNamePrice) external onlyOwner {
        laziNamePrice = _laziNamePrice;
    }

    function set_laziNamePriceWL(uint256 _laziNamePriceWL) external onlyOwner {
        laziNamePriceWL = _laziNamePriceWL;
    }

    function set_saleActiveTime(uint256 _saleActiveTime) external onlyOwner {
        saleActiveTime = _saleActiveTime;
    }

    function set_laziNameImages(string calldata _laziNameImages) external onlyOwner {
        laziNameImages = _laziNameImages;
    }

    function set_royalty(address _receiver, uint96 _feeNumerator) external onlyOwner {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    // Helper Modifiers
    modifier saleActive(uint256 _saleActiveTime) {
        require(block.timestamp > _saleActiveTime, "Nope, sale is not open");
        _;
    }

    // Price Module
    function getPrice(uint256 _qty) public view returns (uint256 priceNow) {
        priceNow = laziNamePrice * _qty;
    }

    function getPriceWL(uint256 _qty) public view returns (uint256 priceNow) {
        priceNow = laziNamePriceWL * _qty;
    }

    modifier pricePaid(uint256 _qty) {
        require(msg.value == getPrice(_qty), "Hey hey, send the right amount of ETH");
        _;
    }

    modifier pricePaidWL(uint256 _qty) {
        require(msg.value == getPriceWL(_qty), "Hey hey, send the right amount of ETH");
        _;
    }

    // System Related
    function _baseURI() internal view override returns (string memory) {
        return laziNameImages;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721A, IERC165, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function autoApproveMarketplace(address _spender) public onlyOwner {
        allowed[_spender] = !allowed[_spender];
    }

    function isApprovedForAll(address _owner, address _operator) public view override(ERC721A, IERC721) returns (bool) {
        if (allowed[_operator]) return true; // Opensea or any other Marketplace
        return super.isApprovedForAll(_owner, _operator);
    }
}
