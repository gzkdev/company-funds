import { ethers } from "hardhat";

async function main() {
  const CompanyFunds = await ethers.getContractFactory("CompanyFunds");
  const companyFunds = await CompanyFunds.deploy();
  await companyFunds.waitForDeployment();

  console.log("CompanyFunds deployed to:", await companyFunds.getAddress());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
