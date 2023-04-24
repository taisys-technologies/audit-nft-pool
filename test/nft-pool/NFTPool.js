const { expect } = require("chai");

describe("TestNFTPool", function () {
  let owner, worker, user, signers;
  let contract, erc721;

  const eventFromReceipt = (receipt, contract, eventName) => {
    let result;
    for (let log of receipt.events) {
      if (log.event === eventName) {
        result = contract.interface.decodeEventLog(
          eventName,
          log.data,
          log.topics
        );
      }
    }
    return result;
  };

  const mintERC721 = async function (to) {
    // mint erc721
    const tx = await erc721.mint(to);
    const receipt = await tx.wait();
    const event = eventFromReceipt(receipt, erc721, "Transfer");
    return event.tokenId;
  };

  beforeEach(async function () {
    [owner, worker, user, ...signers] = await ethers.getSigners();

    const contractFactory = await ethers.getContractFactory("NFTPool");
    const erc721Factory = await ethers.getContractFactory("ERC721Mock");

    // deploy contract
    contract = await contractFactory.deploy(owner.address, worker.address);
    await contract.deployed();

    // deploy erc721
    erc721 = await erc721Factory.deploy();
    await erc721.deployed();
  });

  describe("TransferERC721", function () {
    it("Positive", async function () {
      // mint erc721 to user
      const tokenId = await mintERC721(user.address);

      // user transfer token to pool
      let tx = await erc721
        .connect(user)
        ["safeTransferFrom(address,address,uint256)"](
          user.address,
          contract.address,
          tokenId
        );
      await tx.wait();

      // worker call transferERC721
      tx = await contract
        .connect(worker)
        .transferERC721(erc721.address, user.address, tokenId);
      await tx.wait();

      // verify token ownership
      const owner = await erc721.ownerOf(tokenId);
      expect(owner).to.equal(user.address);
    });

    it("Negative/Forbidden", async function () {
      // mint erc721 to user
      const tokenId = await mintERC721(user.address);

      // user transfer token to pool
      let tx = await erc721
        .connect(user)
        ["safeTransferFrom(address,address,uint256)"](
          user.address,
          contract.address,
          tokenId
        );
      await tx.wait();

      // user call transferERC721
      await expect(
        contract
          .connect(user)
          .transferERC721(erc721.address, user.address, tokenId)
      ).to.be.revertedWithCustomError(contract, "ErrForbidden");
    });
  });

  describe("TransferAdmin", function () {
    it("Positive", async function () {
      const oldAdmin = owner;
      const newAdmin = signers[0];
      const adminRoleId = await contract.DEFAULT_ADMIN_ROLE();

      // oldAdmin call transferAdmin
      let tx = await contract.transferAdmin(newAdmin.address);
      await tx.wait();

      // verify
      expect(await contract.hasRole(adminRoleId, oldAdmin.address)).to.equal(
        true
      );
      expect(await contract.hasRole(adminRoleId, newAdmin.address)).to.equal(
        false
      );
      expect(await contract.transition(oldAdmin.address)).to.equal(
        newAdmin.address
      );
    });

    it("Negative/NotAdmin", async function () {
      const newAdmin = signers[0];

      await expect(
        contract.connect(user).transferAdmin(newAdmin.address)
      ).to.be.revertedWithCustomError(contract, "ErrForbidden");
    });

    it("Negative/AlreadyInTransition", async function () {
      const newAdmin = signers[0];

      // oldAdmin call transferAdmin
      let tx = await contract.transferAdmin(newAdmin.address);
      await tx.wait();

      // call again
      await expect(
        contract.transferAdmin(user.address)
      ).to.be.revertedWithCustomError(contract, "ErrAlreadyInTransition");
    });

    it("Negative/GrantRoleToZeroAddress", async function () {
      await expect(
        contract.transferAdmin("0x0000000000000000000000000000000000000000")
      ).to.be.revertedWithCustomError(contract, "ErrGrantRoleToZeroAddress");
    });

    it("Negative/TransferAdminToSelf", async function () {
      const oldAdmin = owner;

      await expect(
        contract.transferAdmin(oldAdmin.address)
      ).to.be.revertedWithCustomError(contract, "ErrTransferAdminToSelf");
    });
  });

  describe("FinishTransferAdmin", function () {
    it("Positive", async function () {
      const oldAdmin = owner;
      const newAdmin = signers[0];
      const adminRoleId = await contract.DEFAULT_ADMIN_ROLE();

      // oldAdmin call transferAdmin
      let tx = await contract.transferAdmin(newAdmin.address);
      await tx.wait();

      // newAdmin call finishTransferAdmin
      tx = await contract
        .connect(newAdmin)
        .finishTransferAdmin(oldAdmin.address);
      await tx.wait();

      // verify
      expect(await contract.hasRole(adminRoleId, oldAdmin.address)).to.equal(
        false
      );
      expect(await contract.hasRole(adminRoleId, newAdmin.address)).to.equal(
        true
      );
      expect(await contract.transition(oldAdmin.address)).to.equal(
        "0x0000000000000000000000000000000000000000"
      );
    });

    it("Negative/NotNewAdmin", async function () {
      const oldAdmin = owner;
      const newAdmin = signers[0];
      const anyone = signers[1];

      // oldAdmin call transferAdmin
      let tx = await contract.transferAdmin(newAdmin.address);
      await tx.wait();

      // call finishTransferAdmin
      await expect(
        contract.connect(anyone).finishTransferAdmin(oldAdmin.address)
      ).to.be.revertedWithCustomError(contract, "ErrForbidden");
    });

    it("Negative/NotInTransition", async function () {
      const newAdmin = signers[0];

      await expect(
        contract.connect(newAdmin).finishTransferAdmin(owner.address)
      ).to.be.revertedWithCustomError(contract, "ErrNotInTransition");
    });
  });

  describe("CancelTransferAdmin", function () {
    it("Positive", async function () {
      const oldAdmin = owner;
      const newAdmin = signers[0];
      const adminRoleId = await contract.DEFAULT_ADMIN_ROLE();

      // oldAdmin call transferAdmin
      let tx = await contract.transferAdmin(newAdmin.address);
      await tx.wait();

      // oldAdmin call cancelTransferAdmin
      tx = await contract.cancelTransferAdmin();
      await tx.wait();

      // verify
      expect(await contract.hasRole(adminRoleId, oldAdmin.address)).to.equal(
        true
      );
      expect(await contract.hasRole(adminRoleId, newAdmin.address)).to.equal(
        false
      );
      expect(await contract.transition(oldAdmin.address)).to.equal(
        "0x0000000000000000000000000000000000000000"
      );

      await expect(
        contract.connect(newAdmin).finishTransferAdmin(oldAdmin.address)
      ).to.be.revertedWithCustomError(contract, "ErrNotInTransition");
    });

    it("Negative/NotInTransition", async function () {
      await expect(
        contract.cancelTransferAdmin()
      ).to.be.revertedWithCustomError(contract, "ErrNotInTransition");
    });
  });
});
