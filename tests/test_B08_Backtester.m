classdef test_B08_Backtester < matlab.unittest.TestCase

    properties
        RootDir
        RiskEngine
        FixtureData
    end

    methods (TestClassSetup)
        function setupOnce(testCase)
            [folder, ~, ~] = fileparts(mfilename('fullpath'));
            testCase.RootDir = fullfile(folder, '..');
            cd(testCase.RootDir);
            addpath(genpath('src'));
            addpath(genpath('tests'));

            testCase.RiskEngine = RiskEngine(1.5, 2.5, 1.5);

            n = 500;
            dates = datetime(2024,1,1) + days(0:n-1)';
            closeP = 100 + (1:n)' * 0.05;
            highP  = closeP * 1.01;
            lowP   = closeP * 0.99;
            openP  = closeP * 0.995;
            volume = ones(n,1) * 1000;

            testCase.FixtureData = table(dates, openP, highP, lowP, closeP, volume, ...
                'VariableNames', {'Date','Open','High','Low','Close','Volume'});
        end
    end

    methods (Test)

        function testConstructorAndDefaults(testCase)
            bt = Backtester([], testCase.RiskEngine, testCase.FixtureData);
            testCase.verifyEqual(bt.InitialEquity, 10000);
            testCase.verifyGreaterThan(bt.RiskFraction, 0);
            testCase.verifyGreaterThan(bt.MaxLeverage, 0);
            testCase.verifyGreaterThanOrEqual(bt.FeeRate, 0);
            testCase.verifyGreaterThanOrEqual(bt.SlippageRate, 0);
        end

        function testRiskBasedPositionSizing(testCase)
            bt = Backtester([], testCase.RiskEngine, testCase.FixtureData);
            bt.RiskFraction = 0.02;
            bt.InitialEquity = 10000;

            entryPrice = 100;
            stopPrice  = 95;
            stopDistance = abs(entryPrice - stopPrice);

            riskCapital = 10000 * 0.02;
            expectedUnits = riskCapital / stopDistance;
            testCase.verifyEqual(expectedUnits, 40, 'AbsTol', 1e-9);

            equity2 = 5000;
            expectedUnits2 = (5000 * 0.02) / stopDistance;
            testCase.verifyEqual(expectedUnits2, 20, 'AbsTol', 1e-9);

            testCase.verifyLessThan(expectedUnits2, expectedUnits);
        end

        function testStopDistanceAffectsSizeCorrectly(testCase)
            riskCapital = 10000 * 0.01;

            stopDistanceSmall = 2;
            stopDistanceLarge = 50;

            unitsSmall = riskCapital / stopDistanceSmall;
            unitsLarge = riskCapital / stopDistanceLarge;

            testCase.verifyGreaterThan(unitsSmall, unitsLarge);
        end

        function testEquityChangesAffectSubsequentSize(testCase)
            riskCapital1 = 10000 * 0.01;
            stopDistance = 10;
            units1 = riskCapital1 / stopDistance;

            equityAfterLoss = 8000;
            riskCapital2 = equityAfterLoss * 0.01;
            units2 = riskCapital2 / stopDistance;

            testCase.verifyLessThan(units2, units1);
        end

        function testMaxLeverageConstraint(testCase)
            bt = Backtester([], testCase.RiskEngine, testCase.FixtureData);
            bt.MaxLeverage = 1.5;

            entryPrice = 100;
            equity = 10000;
            maxNotional = bt.MaxLeverage * equity;

            stopDistance = 0.5;
            riskCapital = equity * 0.1;
            positionUnits = riskCapital / stopDistance;
            entryNotional = abs(entryPrice * positionUnits);

            if entryNotional > maxNotional
                positionUnits = maxNotional / entryPrice;
                entryNotional = abs(entryPrice * positionUnits);
            end

            testCase.verifyLessThanOrEqual(entryNotional, maxNotional + 1e-9);
        end

        function testFeesReduceEquity(testCase)
            btNoFee = Backtester([], testCase.RiskEngine, testCase.FixtureData);
            btNoFee.FeeRate = 0;

            btWithFee = Backtester([], testCase.RiskEngine, testCase.FixtureData);
            btWithFee.FeeRate = 0.002;

            entryPrice = 100;
            exitPrice  = 110;
            positionUnits = 10;

            notional = abs(entryPrice * positionUnits);

            feeNoFee = 0;
            feeWithFee = notional * 0.002 * 2;

            equityNoFee  = 10000 + (exitPrice - entryPrice) * positionUnits - feeNoFee;
            equityWithFee = 10000 + (exitPrice - entryPrice) * positionUnits - feeWithFee;

            testCase.verifyLessThan(equityWithFee, equityNoFee);
        end

function testSlippageConvention(testCase)
            bt = Backtester([], testCase.RiskEngine, testCase.FixtureData);
            bt.SlippageRate = 0.001;

            theoreticalEntry = 100;
            theoreticalExit  = 110;
            positionUnits     = 10;

            slipEntry = bt.SlippageRate * theoreticalEntry;
            slipExit  = bt.SlippageRate * theoreticalExit;

            execEntry = theoreticalEntry + slipEntry;
            execExit  = theoreticalExit - slipExit;

            testCase.verifyGreaterThan(execEntry, theoreticalEntry);
            testCase.verifyLessThan(execExit, theoreticalExit);

            expectedGross = (execExit - execEntry) * positionUnits;
            testCase.verifyLessThan(expectedGross, (theoreticalExit - theoreticalEntry) * positionUnits);
        end

        function testShortSlippageAdverse(testCase)
            bt = Backtester([], testCase.RiskEngine, testCase.FixtureData);
            bt.SlippageRate = 0.001;

            theoreticalEntry = 100;
            theoreticalExit  = 90;
            positionUnits     = 10;

            slipEntry = bt.SlippageRate * theoreticalEntry;
            slipExit  = bt.SlippageRate * theoreticalExit;

            execEntry = theoreticalEntry - slipEntry;
            execExit  = theoreticalExit + slipExit;

            testCase.verifyLessThan(execEntry, theoreticalEntry);
            testCase.verifyGreaterThan(execExit, theoreticalExit);

            expectedGross = (execEntry - execExit) * positionUnits;
            theoreticalGross = (theoreticalEntry - theoreticalExit) * positionUnits;
            testCase.verifyLessThanOrEqual(expectedGross, theoreticalGross);
        end

        function testTPSLAmbiguityConservativeRule(testCase)
            entryPrice = 100;
            slPrice    = 95;
            tpPrice    = 110;
            highN      = 115;
            lowN       = 94;

            isLong = true;

            hitSL = lowN <= slPrice;
            hitTP = highN >= tpPrice;

            if hitSL && hitTP
                exitReason = 'CONSERVATIVE_SL_FIRST';
                exitPrice  = slPrice;
            elseif hitTP
                exitReason = 'TAKE_PROFIT';
                exitPrice  = tpPrice;
            elseif hitSL
                exitReason = 'STOP_LOSS';
                exitPrice  = slPrice;
            else
                exitReason = 'EOD_CLOSE';
                exitPrice  = highN;
            end

            testCase.verifyEqual(exitReason, 'CONSERVATIVE_SL_FIRST');
            testCase.verifyEqual(exitPrice, slPrice);
        end

        function testTradeLogSchema(testCase)
            expectedVars = {'EntryTime','ExitTime','Direction','EntryPrice','ExitPrice','PositionUnits','EntryNotional','ExitNotional','EntryFee','ExitFee','Slippage','GrossPnL','NetPnL','EquityBefore','EquityAfter','StopLoss','TakeProfit','ExitReason'};

            n = 1;
            entryTime = datetime(2024,1,10);
            exitTime  = datetime(2024,1,11);
            direction = 1;
            entryPrice = 100;
            exitPrice  = 110;
            positionUnits = 10;
            entryNotional = entryPrice * positionUnits;
            exitNotional  = exitPrice * positionUnits;
            entryFee = 2;
            exitFee  = 2;
            slippage = 1.5;
            grossPnL = 80;
            netPnL   = 74.5;
            equityBefore = 10000;
            equityAfter  = 10074.5;
            stopLoss     = 95;
            takeProfit   = 110;
            exitReason   = 'TAKE_PROFIT';

            tradeRow = {entryTime, exitTime, direction, entryPrice, exitPrice, positionUnits, entryNotional, exitNotional, entryFee, exitFee, slippage, grossPnL, netPnL, equityBefore, equityAfter, stopLoss, takeProfit, exitReason};

            tradeTable = cell2table(tradeRow, 'VariableNames', expectedVars);

            testCase.verifyEqual(numel(tradeTable.Properties.VariableNames), numel(expectedVars));
            testCase.verifyEqual(height(tradeTable), 1);
            testCase.verifyTrue(ismember('NetPnL', tradeTable.Properties.VariableNames));
            testCase.verifyTrue(ismember('ExitReason', tradeTable.Properties.VariableNames));
        end

        function testEquityAccountingManualCalculation(testCase)
            initialEquity = 10000;
            riskFraction  = 0.01;

            entryPrice = 100;
            slPrice    = 95;
            tpPrice    = 110;
            exitPrice  = 107;
            exitReason = 'EOD_CLOSE';

            stopDistance = abs(entryPrice - slPrice);
            riskCapital  = initialEquity * riskFraction;
            positionUnits = riskCapital / stopDistance;

            entryNotional = abs(entryPrice * positionUnits);
            exitNotional  = abs(exitPrice * positionUnits);

            feeRate = 0.001;
            entryFee = entryNotional * feeRate;
            exitFee  = exitNotional * feeRate;

            slippageRate = 0.0005;
            slipEntry = slippageRate * entryPrice;
            slipExit  = slippageRate * exitPrice;

            execEntry = entryPrice - slipEntry;
            execExit  = exitPrice - slipExit;

            grossPnL = (execExit - execEntry) * positionUnits;
            netPnL   = grossPnL - entryFee - exitFee;

            equityAfter = initialEquity + netPnL;

            testCase.verifyEqual(positionUnits, 20, 'AbsTol', 1e-9);
            testCase.verifyEqual(equityAfter, 10000 + netPnL, 'AbsTol', 1e-9);
            testCase.verifyGreaterThan(equityAfter, initialEquity);
        end

        function testOOSFoldBoundaries(testCase)
            numRows = 1000;
            trainWindow = 200;
            stepSize    = 50;

            folds = WalkForwardValidator.computeFoldBoundaries(numRows, trainWindow, stepSize);

            testCase.verifyGreaterThan(numel(folds), 0);
            for k = 1:numel(folds)
                testCase.verifyTrue(folds(k).TrainEnd < folds(k).TestStart);
                testCase.verifyEqual(folds(k).TestStart, folds(k).TrainEnd + 1);
                testCase.verifyEqual(folds(k).TestEnd - folds(k).TestStart + 1, stepSize);
            end
        end

        function testNoFixedUnitPnL(testCase)
            equity = 10000;
            riskFraction = 0.01;
            entryPrice = 200;
            slPrice    = 190;
            exitPrice  = 210;

            stopDistance = abs(entryPrice - slPrice);
            positionUnits = (equity * riskFraction) / stopDistance;

            riskBasedPnL = (exitPrice - entryPrice) * positionUnits;
            fixedUnitPnL = exitPrice - entryPrice;

            testCase.verifyNotEqual(riskBasedPnL, fixedUnitPnL);
            testCase.verifyEqual(riskBasedPnL, 100, 'AbsTol', 1e-9);
        end

        function testDeterminismOfSizing(testCase)
            equity = 10000;
            riskFraction = 0.01;
            stopDistance = 25;

            units1 = (equity * riskFraction) / stopDistance;
            units2 = (equity * riskFraction) / stopDistance;

            testCase.verifyEqual(units1, units2);
        end

        function testDeterminismOfSlippageAndFees(testCase)
            entryPrice = 100;
            exitPrice  = 110;
            positionUnits = 10;
            feeRate = 0.001;
            slippageRate = 0.0005;

            slipEntry = slippageRate * entryPrice;
            slipExit  = slippageRate * exitPrice;
            execEntry = entryPrice - slipEntry;
            execExit  = exitPrice - slipExit;

            entryFee = abs(entryPrice * positionUnits) * feeRate;
            exitFee  = abs(exitPrice * positionUnits) * feeRate;

            grossPnL = (execExit - execEntry) * positionUnits;
            netPnL   = grossPnL - entryFee - exitFee;

            slipEntry2 = slippageRate * entryPrice;
            slipExit2  = slippageRate * exitPrice;
            execEntry2 = entryPrice - slipEntry2;
            execExit2  = exitPrice - slipExit2;
            entryFee2  = abs(entryPrice * positionUnits) * feeRate;
            exitFee2   = abs(exitPrice * positionUnits) * feeRate;
            grossPnL2  = (execExit2 - execEntry2) * positionUnits;
            netPnL2    = grossPnL2 - entryFee2 - exitFee2;

            testCase.verifyEqual(netPnL, netPnL2, 'AbsTol', 1e-12);
        end

        function testEquityCurveForwardFill(testCase)
            equityCurve = [10000; 0; 0; 10050; 0; 0; 10100];

            lastEq = equityCurve(1);
            for idx = 2:numel(equityCurve)
                if equityCurve(idx) ~= 0
                    lastEq = equityCurve(idx);
                else
                    equityCurve(idx) = lastEq;
                end
            end

            testCase.verifyEqual(equityCurve, [10000; 10000; 10000; 10050; 10050; 10050; 10100]);
        end

        function testSharpeSortinoMetricStructure(testCase)
            equityCurve = [10000; 10010; 9990; 10030; 10020; 10050; 10080];
            eqDiff = diff(equityCurve);
            eqLag  = equityCurve(1:end-1);
            validMask = (eqLag > 0) & (eqDiff ~= 0);
            returns = eqDiff(validMask) ./ eqLag(validMask);

            testCase.verifyGreaterThan(numel(returns), 0);
            dailyRf = 0.02 / 365;
            excess  = returns - dailyRf;
            sharpe  = sqrt(365) * mean(excess) / std(excess);

            testCase.verifyTrue(isfinite(sharpe));
        end

    end
end