import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

export default buildModule("CompanyFundsModule", (m) => {
  const companyFunds = m.contract("CompanyFunds");

  return { companyFunds };
});
