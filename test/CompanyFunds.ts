import { expect } from "chai";
import { ethers } from "hardhat";
import { CompanyFunds } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("CompanyFunds", function () {
  let companyFunds: CompanyFunds;
  let owner: SignerWithAddress;
  let boardMembers: SignerWithAddress[];
  let nonBoardMember: SignerWithAddress;

  beforeEach(async function () {
    [owner, nonBoardMember, ...boardMembers] = await ethers.getSigners();

    const CompanyFunds = await ethers.getContractFactory("CompanyFunds");
    companyFunds = await CompanyFunds.deploy();

    for (let i = 0; i < 19; i++) {
      // Add 19 more members (owner is already a member)
      await companyFunds.addBoardMember(boardMembers[i].address);
    }
  });

  describe("Board Member Management", function () {
    it("Should add board members correctly", async function () {
      expect(await companyFunds.boardMemberCount()).to.equal(20);
      expect(await companyFunds.boardMembers(boardMembers[0].address)).to.be
        .true;
    });

    it("Should not add more than maximum board members", async function () {
      await expect(
        companyFunds.addBoardMember(nonBoardMember.address)
      ).to.be.revertedWith("Maximum board members reached");
    });

    it("Should remove board members correctly", async function () {
      await companyFunds.removeBoardMember(boardMembers[0].address);
      expect(await companyFunds.boardMembers(boardMembers[0].address)).to.be
        .false;
      expect(await companyFunds.boardMemberCount()).to.equal(19);
    });
  });

  describe("Budget Management", function () {
    it("Should create monthly budget correctly", async function () {
      const amount = ethers.parseEther("100");
      const deadline = (await time.latest()) + 86400; // 1 day from now

      await companyFunds.createMonthlyBudget(amount, deadline);
      expect(await companyFunds.budgetCounter()).to.equal(1);
    });

    it("Should allow board members to sign budget", async function () {
      const amount = ethers.parseEther("100");
      const deadline = (await time.latest()) + 86400;

      await companyFunds.createMonthlyBudget(amount, deadline);

      // Sign with all board members
      for (let i = 0; i < 19; i++) {
        await companyFunds.connect(boardMembers[i]).signBudget(1);
      }
      await companyFunds.connect(owner).signBudget(1);

      expect(await companyFunds.getBudgetSignatures(1)).to.equal(20);
    });

    it("Should not allow double signing", async function () {
      const amount = ethers.parseEther("100");
      const deadline = (await time.latest()) + 86400;

      await companyFunds.createMonthlyBudget(amount, deadline);
      await companyFunds.connect(boardMembers[0]).signBudget(1);

      await expect(
        companyFunds.connect(boardMembers[0]).signBudget(1)
      ).to.be.revertedWith("Already signed");
    });
  });

  describe("Expense Management", function () {
    beforeEach(async function () {
      // Fund the contract
      await owner.sendTransaction({
        to: await companyFunds.getAddress(),
        value: ethers.parseEther("100"),
      });
    });

    it("Should create and execute expense correctly", async function () {
      const amount = ethers.parseEther("50");
      const deadline = (await time.latest()) + 86400;

      // Create budget
      await companyFunds.createMonthlyBudget(amount, deadline);

      // Sign budget with all members
      for (let i = 0; i < 19; i++) {
        await companyFunds.connect(boardMembers[i]).signBudget(1);
      }
      await companyFunds.connect(owner).signBudget(1);

      // Create expense
      await companyFunds.createExpense(
        1,
        amount,
        await boardMembers[0].getAddress(),
        "Test expense"
      );

      // Execute expense
      const initialBalance = await ethers.provider.getBalance(
        boardMembers[0].address
      );
      await companyFunds.executeExpense(1);
      const finalBalance = await ethers.provider.getBalance(
        boardMembers[0].address
      );

      expect(finalBalance - initialBalance).to.equal(amount);
    });

    it("Should not execute expense without sufficient signatures", async function () {
      const amount = ethers.parseEther("50");
      const deadline = (await time.latest()) + 86400;

      await companyFunds.createMonthlyBudget(amount, deadline);
      await companyFunds.createExpense(
        1,
        amount,
        await boardMembers[0].getAddress(),
        "Test expense"
      );

      // Try to execute without signatures
      await expect(companyFunds.executeExpense(1)).to.be.revertedWith(
        "Insufficient signatures"
      );
    });
  });
});
