// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MyToken is ERC1155, Ownable, Pausable, ERC1155Supply {
    constructor() ERC1155("") {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    IERC721 public nft;
    uint256 public nftId = 1;
    bool public isClaimingActive;
    mapping(uint256 => bool) public redeem;

    function set_nft(IERC721 _nft) public onlyOwner {
        nft = _nft;
    }

    function set_nftId(uint256 _nftId) public onlyOwner {
        nftId = _nftId;
    }

    function set_isClaimingActive(bool _isClaimingActive) public onlyOwner {
        isClaimingActive = _isClaimingActive;
    }

    function claim(uint256 tokenId) private {
        require(!redeem[tokenId], "Nft already claimed for this Monster.");
        require(
            msg.sender == nft.ownerOf(tokenId),
            "You are not the owner of this Monster."
        );
        redeem[tokenId] = true;
    }

    function mintClaim(uint256[] memory tokenIds) public {
        require(isClaimingActive, "Claim is not active.");
        uint256 qty = tokenIds.length;
        for (uint256 i = 0; i < qty; i++) claim(tokenIds[i]);

        for (uint256 i = 0; i < qty; i++) _mint(msg.sender, nftId, qty, "");
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        _mint(account, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) whenNotPaused {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
