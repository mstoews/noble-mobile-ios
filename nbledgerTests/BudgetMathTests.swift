//
//  BudgetMathTests.swift
//  nbledgerTests
//
//  Unit tests for the budget generator/spread math (BudgetEditorService.swift),
//  mirroring noble-web's budget-generator.spec.ts so the ported logic stays
//  behaviour-compatible.
//

import Foundation
import Testing
@testable import nbledger

@Suite struct BudgetMathTests {

    // MARK: generate

    @Test func generateWeightOneGrowthZeroReproducesPriorActuals() {
        let prior = (1...12).map { Double($0) * 100 }   // 100…1200
        let existing = Array(repeating: 999.0, count: 12)
        let out = BudgetMath.generate(priorActual: prior, existingBudget: existing,
                                      growthPct: 0, weight: 1)
        #expect(out == prior)   // weight=1 ignores existing; growth=0 is identity
    }

    @Test func generateAppliesGrowthToPriorActuals() {
        let prior = Array(repeating: 100.0, count: 12)
        let out = BudgetMath.generate(priorActual: prior, existingBudget: Array(repeating: 0, count: 12),
                                      growthPct: 10, weight: 1)
        #expect(out.allSatisfy { abs($0 - 110.0) < 0.001 })
    }

    @Test func generateWeightZeroKeepsExistingBudget() {
        let existing = (1...12).map { Double($0) * 50 }
        let out = BudgetMath.generate(priorActual: Array(repeating: 9999, count: 12),
                                      existingBudget: existing, growthPct: 25, weight: 0)
        #expect(out == existing)   // weight=0 ignores prior actuals entirely
    }

    @Test func generateBlendsHalfway() {
        let prior = Array(repeating: 200.0, count: 12)      // grown by 0% stays 200
        let existing = Array(repeating: 100.0, count: 12)
        let out = BudgetMath.generate(priorActual: prior, existingBudget: existing,
                                      growthPct: 0, weight: 0.5)
        #expect(out.allSatisfy { abs($0 - 150.0) < 0.001 })  // (200*.5 + 100*.5)
    }

    // MARK: spread

    @Test func spreadEvenDistributesEqually() {
        let out = BudgetMath.spread(annual: 1200, mode: .even)
        #expect(out.allSatisfy { abs($0 - 100.0) < 0.001 })
        #expect(abs(out.reduce(0, +) - 1200) < 0.001)
    }

    @Test func spreadSeasonalMatchesCurveAndSumsExactly() {
        let annual = 1200.0
        let out = BudgetMath.spread(annual: annual, mode: .seasonal)
        // Curve sums to 12, so month i = annual * curve[i] / 12.
        #expect(abs(out[0] - 95.0) < 0.001)   // 1200 * 0.95 / 12
        #expect(abs(out[6] - 85.0) < 0.001)   // 1200 * 0.85 / 12
        #expect(abs(out.reduce(0, +) - annual) < 0.001)
    }

    @Test func spreadAbsorbsRoundingRemainderInMonth12() {
        let annual = 1000.0   // /12 doesn't divide evenly
        let out = BudgetMath.spread(annual: annual, mode: .even)
        #expect(abs(out.reduce(0, +) - annual) < 0.001)   // exact despite rounding
    }

    @Test func spreadZeroIsAllZeros() {
        #expect(BudgetMath.spread(annual: 0, mode: .seasonal).allSatisfy { $0 == 0 })
        #expect(BudgetMath.spread(annual: 0, mode: .even).allSatisfy { $0 == 0 })
    }
}
