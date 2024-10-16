const {
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("BankAccount", function () {
    async function deployBankAccount() {
        
        const [addr0, addr1, addr2, addr3, addr4] = await ethers.getSigners();

        const bankAccount = await ethers.deployContract("BankAccount");
        // const bankAccount = await BankAccount.deploy();

        return { bankAccount, addr0, addr1, addr2, addr3, addr4 };
    }

    async function deployBankAccountWithAccounts(owners = 1,deposit = 0,withdrawalAmounts = []) {
        
        const {bankAccount,addr0, addr1, addr2, addr3, addr4} = await loadFixture(deployBankAccount);

        const addresses = [];

        if(owners == 2){
            addresses = [addr1.address];
        }else if(owners == 3){
            addresses = [addr1.address,addr2.address];
        }else if(owners == 4){
            addresses = [addr1.address,addr2.address,addr3.address];
        }

        await bankAccount.connect(addr0).createAccount(addresses);

        if(deposit > 0){
            await bankAccount.connect(addr0).deposit(0,{value : deposit.toString()});
        }

        for(const withdrawalAmount of withdrawalAmounts){
            await bankAccount.connect(addr0).requestWithdrawl(withdrawalAmount);
        }

        return {bankAccount,addr0, addr1, addr2, addr3, addr4};
    }

    describe("Deployment",()=> {
        it("Should deploy without Error", async ()=>{
        await loadFixture(deployBankAccount)
        });
    });

    describe("create an account",()=> {
        it("should allow creating a single account",async () => {
            const {bankAccount, addr0} = await loadFixture(deployBankAccount);
            await bankAccount.connect(addr0).createAccount([]);
            const accounts = await bankAccount.connect(addr0).getAccounts();
            expect(await accounts.length).to.equal(1);
        })

        it("should allow creating double accounts",async () => {
            const {bankAccount, addr0, addr1} = await loadFixture(deployBankAccount);
            await bankAccount.connect(addr0).createAccount([addr1.address]);

            const account1 = await bankAccount.connect(addr0).getAccounts();
            expect(await account1.length).to.equal(1);

            const account2 = await bankAccount.connect(addr1).getAccounts();
            expect(await account2.length).to.equal(1);
        })

        it("should allow creating triple accounts",async () => {
            const {bankAccount, addr0, addr1, addr2} = await loadFixture(deployBankAccount);
            await bankAccount.connect(addr0).createAccount([addr1.address,addr2.address]);

            const account1 = await bankAccount.connect(addr0).getAccounts();
            expect(await account1.length).to.equal(1);

            const account2 = await bankAccount.connect(addr1).getAccounts();
            expect(await account2.length).to.equal(1);

            const account3 = await bankAccount.connect(addr2).getAccounts();
            expect(await account3.length).to.equal(1);
        })

        it("should not allow to create duplicate owners",async()=>{
            const {bankAccount, addr0} = await loadFixture(deployBankAccount);
            
            await expect(bankAccount.connect(addr0).createAccount([addr0.address])).to.be.reverted;
        })

        it("should not allow to create an acoount with 5 users",async()=>{
            const {bankAccount, addr0,addr1,addr2,addr3,addr4} = await loadFixture(deployBankAccount);
            await expect(bankAccount.connect(addr0).createAccount([
                addr0.address,addr1.address,addr2.address,addr3.address,addr4.address
            ])).to.be.reverted;
        })
    });

    describe("depositing",()=> {
        it("should allow deposit from owners account",async ()=>{
            const {bankAccount, addr0} = await deployBankAccountWithAccounts(1);

            await expect(
                bankAccount.connect(addr0).deposit(0,{value: "100"})
            ).to.changeEtherBalances([bankAccount,addr0],["100","-100"]);
        });

        it("should not allow deposit from owners account",async ()=>{
            const {bankAccount, addr1} = await deployBankAccountWithAccounts(1);

            await expect(
                bankAccount.connect(addr1).deposit(0,{value: "100"})
            ).to.reverted;
        });
    })

});
