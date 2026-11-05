describe("Money", function()
	local Money

	before_each(function()
		Money = LoadAddonFile("src/Money.lua").Money
	end)

	local function assertError(text)
		local copper, err = Money.Parse(text)
		assert.is_nil(copper)
		assert.are.equal(Money.ERROR, err)
	end

	describe("constants", function()
		it("exposes MIN, MAX and ERROR from the contract", function()
			assert.are.equal(1, Money.MIN)
			assert.are.equal(9999999999, Money.MAX)
			assert.are.equal("Enter an amount like 5, 1g 50s or 1.5g", Money.ERROR)
		end)
	end)

	describe("Parse", function()
		it("AC-01-01 reads a plain integer as gold", function()
			assert.are.equal(50000, Money.Parse("5"))
		end)

		it("AC-01-02 reads one decimal as silver", function()
			assert.are.equal(15000, Money.Parse("1.5"))
		end)

		it("AC-01-03 reads two decimals as silver", function()
			assert.are.equal(10500, Money.Parse("1.05"))
		end)

		it("AC-01-04 reads decimal gold with a g suffix", function()
			assert.are.equal(15000, Money.Parse("1.5g"))
		end)

		it("AC-01-05 reads a gold part", function()
			assert.are.equal(10000, Money.Parse("1g"))
		end)

		it("AC-01-06 reads a silver part", function()
			assert.are.equal(5000, Money.Parse("50s"))
		end)

		it("AC-01-07 reads parts without spaces", function()
			assert.are.equal(15000, Money.Parse("1g50s"))
		end)

		it("AC-01-08 reads gold, silver and copper with spaces", function()
			assert.are.equal(15045, Money.Parse("1g 50s 45c"))
		end)

		it("AC-01-09 accepts parts in any order", function()
			assert.are.equal(10045, Money.Parse("45c 1g"))
		end)

		it("AC-01-10 trims spaces and ignores case", function()
			assert.are.equal(20000, Money.Parse("  2G "))
		end)

		it("AC-01-11 normalises silver over 99", function()
			assert.are.equal(15000, Money.Parse("150s"))
		end)

		it("AC-01-12 rejects three decimals", function()
			assertError("1.555")
		end)

		it("AC-01-13 rejects a decimal on silver", function()
			assertError("1.5s")
		end)

		it("AC-01-14 rejects decimal gold combined with other parts", function()
			assertError("1.5g 20s")
		end)

		it("AC-01-15 rejects a repeated suffix", function()
			assertError("1g 1g")
		end)

		it("AC-01-16 rejects zero", function()
			assertError("0")
			assertError("0c")
		end)

		it("AC-01-17 rejects empty, nil and non-numeric text", function()
			assertError("")
			assertError(nil)
			assertError("abc")
			assertError("1g abc")
		end)

		it("AC-01-18 rejects an amount over MAX", function()
			assertError("1000000g")
		end)

		it("AC-01-19 accepts exactly MAX", function()
			assert.are.equal(9999999999, Money.Parse("999999g 99s 99c"))
		end)
	end)

	describe("Format", function()
		it("AC-01-20 shows whole gold", function()
			assert.are.equal("1g", Money.Format(10000))
		end)

		it("AC-01-21 shows silver only", function()
			assert.are.equal("50s", Money.Format(5000))
		end)

		it("AC-01-22 shows all three parts", function()
			assert.are.equal("1g 50s 45c", Money.Format(15045))
		end)

		it("AC-01-23 skips a zero middle part", function()
			assert.are.equal("1g 45c", Money.Format(10045))
		end)

		it("AC-01-24 shows zero as 0c", function()
			assert.are.equal("0c", Money.Format(0))
		end)

		it("AC-01-25 shows several gold without separators", function()
			assert.are.equal("4g", Money.Format(40000))
		end)

		it("AC-01-26 raises on non-integer, negative or non-number input", function()
			assert.has_error(function() Money.Format(1.5) end)
			assert.has_error(function() Money.Format(-1) end)
			assert.has_error(function() Money.Format("1") end)
		end)
	end)

	describe("Split", function()
		it("AC-01-27 returns gold, silver and copper", function()
			local gold, silver, copper = Money.Split(15045)
			assert.are.equal(1, gold)
			assert.are.equal(50, silver)
			assert.are.equal(45, copper)
		end)
	end)

	describe("round trip", function()
		it("AC-01-28 Parse(Format(n)) gives n back", function()
			for _, n in ipairs({ 1, 99, 100, 10000, 15045, 9999999999 }) do
				assert.are.equal(n, Money.Parse(Money.Format(n)))
			end
		end)
	end)
end)
