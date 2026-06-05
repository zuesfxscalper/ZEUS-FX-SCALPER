//+------------------------------------------------------------------+
//|                                              ZEUS SCALPER Ai.mq5 |
//|                                     Copyright 2026, CYCLONE POSH |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, CYCLONE POSH"
#property link      "https://www.mql5.com"
#property version   "1.05"
#property description "ZEUS SCALPER Ai - Advanced Scalping EA with ATR-based SL/TP"
//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Expert\Expert.mqh>
//--- available signals
#include <Expert\Signal\SignalMA.mqh>
#include <Expert\Signal\SignalBullsPower.mqh>
#include <Expert\Signal\SignalBearsPower.mqh>
#include <Expert\Signal\SignalStoch.mqh>
//--- available trailing
#include <Expert\Trailing\TrailingNone.mqh>
//--- available money management
#include <Expert\Money\MoneyFixedLot.mqh>
//--- Trade class
#include <Trade\Trade.mqh>
//+------------------------------------------------------------------+
//| Custom Trade Comment Settings                                    |
//+------------------------------------------------------------------+
#define TRADE_COMMENT "ZEUS SCALPER Ai"  // Custom trade comment
#define VERSION_NUMBER "1.05"
#define EA_NAME "ZEUS SCALPER Ai"

// Trade type enum
enum TradeType { BUY_TRADE = 1, SELL_TRADE = -1, NO_TRADE = 0 };

//+------------------------------------------------------------------+
//| Inputs                                                           |
//+------------------------------------------------------------------+
//--- inputs for expert
input string             Expert_Title                 = EA_NAME;          // Document name
ulong                    Expert_MagicNumber           = 53927483;         // Magic Number
bool                     Expert_EveryTick             = false;            // Trade on every tick

//--- inputs for dashboard
input bool               ShowDashboard                = true;             // Show trading dashboard
input color              DashboardColor               = clrWhite;         // Dashboard text color
input int                DashboardX                   = 10;               // Dashboard X position
input int                DashboardY                   = 20;               // Dashboard Y position
input int                DashboardFontSize            = 10;               // Dashboard font size

//--- inputs for main signal - FIXED THRESHOLDS
input int                Signal_ThresholdOpen         = 18;               // Signal threshold value to open [0...100]
input int                Signal_ThresholdClose        = 12;               // Signal threshold value to close [0...100]
input double             Signal_PriceLevel            = 0.0;              // Price level to execute a deal

//--- ATR Settings (NEW)
input int                ATR_Period                   = 14;               // ATR Period
input double             ATR_SL_Multiplier            = 1.5;              // ATR multiplier for Stop Loss
input double             ATR_TP_Multiplier            = 2.0;              // ATR multiplier for Take Profit
input int                Signal_Expiration            = 4;                // Expiration of pending orders (in bars)

//--- MA Filter 1 (Trend Direction - 200 EMA)
input int                Signal_0_MA_PeriodMA         = 200;              // Moving Average(200,0,...) Period of averaging
input int                Signal_0_MA_Shift            = 0;                // Moving Average(200,0,...) Time shift
input ENUM_MA_METHOD     Signal_0_MA_Method           = MODE_EMA;         // Moving Average(200,0,...) Method of averaging
input ENUM_APPLIED_PRICE Signal_0_MA_Applied         = PRICE_CLOSE;      // Moving Average(200,0,...) Prices series
input double             Signal_0_MA_Weight           = 0.15;             // Moving Average(200,0,...) Weight [0...1.0]

//--- MA Filter 2 (Entry Confirmation - 50 EMA)
input int                Signal_1_MA_PeriodMA         = 50;               // Moving Average(50,0,...) Period of averaging
input int                Signal_1_MA_Shift            = 0;                // Moving Average(50,0,...) Time shift
input ENUM_MA_METHOD     Signal_1_MA_Method           = MODE_EMA;         // Moving Average(50,0,...) Method of averaging
input ENUM_APPLIED_PRICE Signal_1_MA_Applied         = PRICE_CLOSE;      // Moving Average(50,0,...) Prices series
input double             Signal_1_MA_Weight           = 0.15;             // Moving Average(50,0,...) Weight [0...1.0]

//--- Bulls Power (Uptrend Momentum)
input int                Signal_BullsPower_PeriodBulls = 13;              // Bulls Power(13) Period of calculation
input double             Signal_BullsPower_Weight     = 0.25;             // Bulls Power(13) Weight [0...1.0]

//--- Bears Power (Downtrend Momentum)
input int                Signal_BearsPower_PeriodBears = 13;              // Bears Power(13) Period of calculation
input double             Signal_BearsPower_Weight     = 0.25;             // Bears Power(13) Weight [0...1.0]

//--- Stochastic (Confirmation of Momentum)
input int                Signal_Stoch_PeriodK         = 14;               // Stochastic(14,3,3,...) K-period
input int                Signal_Stoch_PeriodD         = 3;                // Stochastic(14,3,3,...) D-period
input int                Signal_Stoch_PeriodSlow      = 3;                // Stochastic(14,3,3,...) Period of slowing
input ENUM_STO_PRICE     Signal_Stoch_Applied         = STO_LOWHIGH;      // Stochastic(14,3,3,...) Prices to apply to
input double             Signal_Stoch_Weight          = 0.20;             // Stochastic(14,3,3,...) Weight [0...1.0]

//--- money
input double             Money_FixLot_Percent         = 10.0;             // Percent
input double             Money_FixLot_Lots            = 0.1;              // Fixed volume

//--- Manual Trading Control
input bool               EnableAutoTrade              = true;             // Enable automatic trading
input bool               EnableDebugLogging            = true;             // Enable debug messages

//+------------------------------------------------------------------+
//| Global expert object                                             |
//+------------------------------------------------------------------+
CExpert ExtExpert;
CTrade TradeExecutor;

// Statistics variables
int totalTrades = 0;
int winningTrades = 0;
int losingTrades = 0;
double totalProfit = 0.0;
double totalLoss = 0.0;
datetime lastTradeTime = 0;
int lastTradeType = 0;  // 1 = BUY, -1 = SELL

// Signal tracking
int lastSignalStrength = 0;
TradeType lastSignalType = NO_TRADE;

// ATR Handle
int atr_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Function to get custom trade comment with details                |
//+------------------------------------------------------------------+
string GetTradeComment() {
   string comment = TRADE_COMMENT;
   comment += " | v" + VERSION_NUMBER;
   comment += " | MA:" + IntegerToString(Signal_0_MA_PeriodMA);
   comment += "/" + IntegerToString(Signal_1_MA_PeriodMA);
   comment += " | ATR:" + IntegerToString(ATR_Period);
   return comment;
}

//+------------------------------------------------------------------+
//| Function to calculate ATR value                                  |
//+------------------------------------------------------------------+
double GetATR() {
   double atr_buffer[1];
   
   if(atr_handle == INVALID_HANDLE) {
      atr_handle = iATR(Symbol(), Period(), ATR_Period);
   }
   
   if(atr_handle != INVALID_HANDLE && CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) > 0) {
      return atr_buffer[0];
   }
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Function to convert ATR to points                                |
//+------------------------------------------------------------------+
double ATRToPoints(double atr_value) {
   double point_value = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   if(point_value == 0) point_value = 0.0001;
   
   return atr_value / point_value;
}

//+------------------------------------------------------------------+
//| Enhanced: Get buy signal strength (0-100)                        |
//+------------------------------------------------------------------+
int GetBuySignalStrength() {
   int bullish_signals = 0;
   int total_signals = 5;
   
   // Check MA(200) - Trend filter (above = bullish)
   double ma200 = iMA(Symbol(), Period(), Signal_0_MA_PeriodMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   if(Close[0] > ma200) {
      bullish_signals += 2;  // Higher weight for trend
   }
   
   // Check MA(50) - Entry confirmation (above = bullish)
   double ma50 = iMA(Symbol(), Period(), Signal_1_MA_PeriodMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   if(Close[0] > ma50) {
      bullish_signals += 2;  // Higher weight for entry
   }
   
   // Check Bulls Power
   double bulls_buffer[1];
   int bulls_handle = iCustom(Symbol(), Period(), "Examples\\BullsPower", Signal_BullsPower_PeriodBulls);
   if(CopyBuffer(bulls_handle, 0, 0, 1, bulls_buffer) > 0 && bulls_buffer[0] > 0) {
      bullish_signals += 1;
   }
   
   // Check Stochastic K > D (uptrend)
   double stoch_k[1], stoch_d[1];
   int stoch_handle = iStochastic(Symbol(), Period(), Signal_Stoch_PeriodK, Signal_Stoch_PeriodD, Signal_Stoch_PeriodSlow, PRICE_CLOSE);
   if(CopyBuffer(stoch_handle, 0, 0, 1, stoch_k) > 0 && CopyBuffer(stoch_handle, 1, 0, 1, stoch_d) > 0) {
      if(stoch_k[0] > stoch_d[0] && stoch_k[0] < 80) {  // Avoid overbought
         bullish_signals += 1;
      }
   }
   
   // Calculate percentage (0-100)
   int strength = (bullish_signals * 100) / (total_signals * 2);
   if(strength > 100) strength = 100;
   
   return strength;
}

//+------------------------------------------------------------------+
//| Enhanced: Get sell signal strength (0-100)                       |
//+------------------------------------------------------------------+
int GetSellSignalStrength() {
   int bearish_signals = 0;
   int total_signals = 5;
   
   // Check MA(200) - Trend filter (below = bearish)
   double ma200 = iMA(Symbol(), Period(), Signal_0_MA_PeriodMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   if(Close[0] < ma200) {
      bearish_signals += 2;  // Higher weight for trend
   }
   
   // Check MA(50) - Entry confirmation (below = bearish)
   double ma50 = iMA(Symbol(), Period(), Signal_1_MA_PeriodMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   if(Close[0] < ma50) {
      bearish_signals += 2;  // Higher weight for entry
   }
   
   // Check Bears Power
   double bears_buffer[1];
   int bears_handle = iCustom(Symbol(), Period(), "Examples\\BearsPower", Signal_BearsPower_PeriodBears);
   if(CopyBuffer(bears_handle, 0, 0, 1, bears_buffer) > 0 && bears_buffer[0] < 0) {
      bearish_signals += 1;
   }
   
   // Check Stochastic K < D (downtrend)
   double stoch_k[1], stoch_d[1];
   int stoch_handle = iStochastic(Symbol(), Period(), Signal_Stoch_PeriodK, Signal_Stoch_PeriodD, Signal_Stoch_PeriodSlow, PRICE_CLOSE);
   if(CopyBuffer(stoch_handle, 0, 0, 1, stoch_k) > 0 && CopyBuffer(stoch_handle, 1, 0, 1, stoch_d) > 0) {
      if(stoch_k[0] < stoch_d[0] && stoch_k[0] > 20) {  // Avoid oversold
         bearish_signals += 1;
      }
   }
   
   // Calculate percentage (0-100)
   int strength = (bearish_signals * 100) / (total_signals * 2);
   if(strength > 100) strength = 100;
   
   return strength;
}

//+------------------------------------------------------------------+
//| Enhanced: Check if we should open a trade                        |
//+------------------------------------------------------------------+
TradeType CheckTradeSignal() {
   // Don't trade if already in a position
   if(PositionsTotal() > 0) {
      return NO_TRADE;
   }
   
   int buy_strength = GetBuySignalStrength();
   int sell_strength = GetSellSignalStrength();
   
   lastSignalStrength = (buy_strength > sell_strength) ? buy_strength : sell_strength;
   
   // BUY Signal
   if(buy_strength >= Signal_ThresholdOpen && buy_strength > sell_strength) {
      lastSignalType = BUY_TRADE;
      if(EnableDebugLogging) {
         printf("[%s] BUY Signal: Strength=%d%% (Threshold=%d%%)", EA_NAME, buy_strength, Signal_ThresholdOpen);
      }
      return BUY_TRADE;
   }
   
   // SELL Signal
   if(sell_strength >= Signal_ThresholdOpen && sell_strength > buy_strength) {
      lastSignalType = SELL_TRADE;
      if(EnableDebugLogging) {
         printf("[%s] SELL Signal: Strength=%d%% (Threshold=%d%%)", EA_NAME, sell_strength, Signal_ThresholdOpen);
      }
      return SELL_TRADE;
   }
   
   return NO_TRADE;
}

//+------------------------------------------------------------------+
//| Enhanced: Execute BUY trade with ATR-based SL/TP                 |
//+------------------------------------------------------------------+
bool ExecuteBuyTrade() {
   if(!EnableAutoTrade) return false;
   
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double atr = GetATR();
   double atr_points = ATRToPoints(atr);
   
   // Calculate SL and TP based on ATR
   double sl = ask - (atr_points * ATR_SL_Multiplier) * Point();
   double tp = ask + (atr_points * ATR_TP_Multiplier) * Point();
   double lot = Money_FixLot_Lots;
   
   bool result = TradeExecutor.Buy(lot, Symbol(), ask, sl, tp, GetTradeComment());
   
   if(result) {
      lastTradeTime = TimeCurrent();
      lastTradeType = 1;  // BUY
      if(EnableDebugLogging) {
         printf("[%s] BUY Executed: Price=%.5f | ATR=%.5f | SL=%.5f (%d pts) | TP=%.5f (%d pts) | Lot=%.2f", 
                EA_NAME, ask, atr, sl, (int)atr_points * (int)ATR_SL_Multiplier, tp, (int)atr_points * (int)ATR_TP_Multiplier, lot);
      }
   } else {
      if(EnableDebugLogging) {
         printf("[%s] BUY Failed: %s", EA_NAME, TradeExecutor.ResultComment());
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Enhanced: Execute SELL trade with ATR-based SL/TP                |
//+------------------------------------------------------------------+
bool ExecuteSellTrade() {
   if(!EnableAutoTrade) return false;
   
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double atr = GetATR();
   double atr_points = ATRToPoints(atr);
   
   // Calculate SL and TP based on ATR
   double sl = bid + (atr_points * ATR_SL_Multiplier) * Point();
   double tp = bid - (atr_points * ATR_TP_Multiplier) * Point();
   double lot = Money_FixLot_Lots;
   
   bool result = TradeExecutor.Sell(lot, Symbol(), bid, sl, tp, GetTradeComment());
   
   if(result) {
      lastTradeTime = TimeCurrent();
      lastTradeType = -1;  // SELL
      if(EnableDebugLogging) {
         printf("[%s] SELL Executed: Price=%.5f | ATR=%.5f | SL=%.5f (%d pts) | TP=%.5f (%d pts) | Lot=%.2f", 
                EA_NAME, bid, atr, sl, (int)atr_points * (int)ATR_SL_Multiplier, tp, (int)atr_points * (int)ATR_TP_Multiplier, lot);
      }
   } else {
      if(EnableDebugLogging) {
         printf("[%s] SELL Failed: %s", EA_NAME, TradeExecutor.ResultComment());
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Function to update trading statistics                            |
//+------------------------------------------------------------------+
void UpdateTradingStats() {
   totalTrades = 0;
   winningTrades = 0;
   losingTrades = 0;
   totalProfit = 0.0;
   totalLoss = 0.0;
   
   int deals = HistoryDealsTotal();
   
   for(int i = 0; i < deals; i++) {
      ulong ticket = HistoryDealGetTicket(i);
      
      if(ticket > 0) {
         ulong magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         
         if(magic == Expert_MagicNumber) {
            ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
            
            if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL) {
               totalTrades++;
               double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
               totalProfit += profit;
               
               if(profit > 0) {
                  winningTrades++;
               } else {
                  losingTrades++;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Function to draw text dashboard                                  |
//+------------------------------------------------------------------+
void DrawDashboard() {
   if(!ShowDashboard) return;
   
   UpdateTradingStats();
   
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double ma200 = iMA(Symbol(), Period(), Signal_0_MA_PeriodMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ma50 = iMA(Symbol(), Period(), Signal_1_MA_PeriodMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double atr = GetATR();
   double atr_points = ATRToPoints(atr);
   
   string dashboardText = "";
   dashboardText += "╔════════════════════════════════════╗\n";
   dashboardText += "║    " + EA_NAME + " v" + VERSION_NUMBER + " - DASHBOARD    ║\n";
   dashboardText += "╠════════════════════════════════════╣\n";
   dashboardText += "║ Symbol: " + Symbol() + " | TF: " + IntegerToString(Period()) + "m\n";
   dashboardText += "║ Bid: " + DoubleToString(bid, 5) + " | Ask: " + DoubleToString(ask, 5) + "\n";
   dashboardText += "║ MA(200): " + DoubleToString(ma200, 5) + " | MA(50): " + DoubleToString(ma50, 5) + "\n";
   dashboardText += "╠════════════════════════════════════╣\n";
   dashboardText += "║ ATR SETTINGS\n";
   dashboardText += "║ ATR Value: " + DoubleToString(atr, 5) + " (" + DoubleToString(atr_points, 0) + " pts)\n";
   dashboardText += "║ SL Multiplier: " + DoubleToString(ATR_SL_Multiplier, 2) + "x → " + DoubleToString(atr_points * ATR_SL_Multiplier, 0) + " pts\n";
   dashboardText += "║ TP Multiplier: " + DoubleToString(ATR_TP_Multiplier, 2) + "x → " + DoubleToString(atr_points * ATR_TP_Multiplier, 0) + " pts\n";
   dashboardText += "╠════════════════════════════════════╣\n";
   dashboardText += "║ SIGNAL SETTINGS\n";
   dashboardText += "║ Open Threshold: " + IntegerToString(Signal_ThresholdOpen) + "%\n";
   dashboardText += "║ Close Threshold: " + IntegerToString(Signal_ThresholdClose) + "%\n";
   dashboardText += "╠════════════════════════════════════╣\n";
   dashboardText += "║ CURRENT SIGNALS\n";
   dashboardText += "║ Buy Strength: " + IntegerToString(GetBuySignalStrength()) + "%\n";
   dashboardText += "║ Sell Strength: " + IntegerToString(GetSellSignalStrength()) + "%\n";
   dashboardText += "║ Last Signal: " + (lastSignalType == BUY_TRADE ? "BUY" : (lastSignalType == SELL_TRADE ? "SELL" : "NONE")) + " @ " + IntegerToString(lastSignalStrength) + "%\n";
   dashboardText += "╠════════════════════════════════════╣\n";
   dashboardText += "║ TRADING STATISTICS\n";
   dashboardText += "║ Total Trades: " + IntegerToString(totalTrades) + "\n";
   dashboardText += "║ Winning: " + IntegerToString(winningTrades) + " | Losing: " + IntegerToString(losingTrades) + "\n";
   
   double winRate = (totalTrades > 0) ? (double)winningTrades / totalTrades * 100 : 0;
   dashboardText += "║ Win Rate: " + DoubleToString(winRate, 1) + "%\n";
   dashboardText += "║ Total P&L: " + DoubleToString(totalProfit, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "\n";
   dashboardText += "╠════════════════════════════════════╣\n";
   dashboardText += "║ STATUS: " + (PositionsTotal() > 0 ? "IN TRADE 🟢" : "WAITING 🔴") + "\n";
   dashboardText += "║ AutoTrade: " + (EnableAutoTrade ? "ON ✓" : "OFF ✗") + "\n";
   dashboardText += "╚════════════════════════════════════╝\n";
   
   Comment(dashboardText);
}

//+------------------------------------------------------------------+
//| Initialization function of the expert                            |
//+------------------------------------------------------------------+
int OnInit() {
   // Initialize Trade executor
   TradeExecutor.SetExpertMagicNumber(Expert_MagicNumber);
   TradeExecutor.LogLevel(LOG_LEVEL_ERRORS);
   
   // Initialize ATR indicator
   atr_handle = iATR(Symbol(), Period(), ATR_Period);
   if(atr_handle == INVALID_HANDLE) {
      printf("[%s] ERROR: Failed to initialize ATR indicator", EA_NAME);
      return(INIT_FAILED);
   }
   
   printf("\n╔════════════════════════════════════╗");
   printf("\n║  " + EA_NAME + " v" + VERSION_NUMBER + " - INITIALIZED");
   printf("\n║  Magic Number: %d", Expert_MagicNumber);
   printf("\n║  Trade Comment: %s", GetTradeComment());
   printf("\n║  Auto Trade: %s", EnableAutoTrade ? "ENABLED" : "DISABLED");
   printf("\n║  ATR Period: %d | SL: %.2fx | TP: %.2fx", ATR_Period, ATR_SL_Multiplier, ATR_TP_Multiplier);
   printf("\n║  Buy/Sell Logic: ENHANCED");
   printf("\n╚════════════════════════════════════╝\n");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialization function of the expert                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   // Release ATR indicator
   if(atr_handle != INVALID_HANDLE) {
      IndicatorRelease(atr_handle);
   }
   
   Comment("");
   printf("[%s] Deinitialized (Reason: %d)", EA_NAME, reason);
}

//+------------------------------------------------------------------+
//| "Tick" event handler function                                    |
//+------------------------------------------------------------------+
void OnTick() {
   // Draw dashboard
   DrawDashboard();
   
   // Check for trade signal
   TradeType signal = CheckTradeSignal();
   
   // Execute trades
   if(signal == BUY_TRADE) {
      ExecuteBuyTrade();
   } else if(signal == SELL_TRADE) {
      ExecuteSellTrade();
   }
}

//+------------------------------------------------------------------+
//| "Trade" event handler function                                    |
//+------------------------------------------------------------------+
void OnTrade() {
   UpdateTradingStats();
   
   if(EnableDebugLogging) {
      printf("[%s] Trade Event - Total Trades: %d, Profit: %.2f", 
             EA_NAME, totalTrades, totalProfit);
   }
}

//+------------------------------------------------------------------+
//| "Timer" event handler function                                    |
//+------------------------------------------------------------------+
void OnTimer() {
   // Reserved for future use
}

//+------------------------------------------------------------------+
