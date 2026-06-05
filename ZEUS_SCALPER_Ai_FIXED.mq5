//+------------------------------------------------------------------+
//|                                              ZEUS SCALPER Ai.mq5 |
//|                                     Copyright 2026, CYCLONE POSH |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, CYCLONE POSH"
#property link      "https://www.mql5.com"
#property version   "1.06"
#property description "ZEUS SCALPER Ai - Advanced Scalping EA with ATR, RSI, MACD, CCI Algorithms"
//+------------------------------------------------------------------+
//| Include                                                          |
//+------------------------------------------------------------------+
#include <Expert\Expert.mqh>
#include <Trade\Trade.mqh>
//+------------------------------------------------------------------+
//| Custom Trade Comment Settings                                    |
//+------------------------------------------------------------------+
#define TRADE_COMMENT "ZEUS SCALPER Ai"
#define VERSION_NUMBER "1.06"
#define EA_NAME "ZEUS SCALPER Ai"

enum TradeType { BUY_TRADE = 1, SELL_TRADE = -1, NO_TRADE = 0 };

//+------------------------------------------------------------------+
//| Inputs - Core Settings                                           |
//+------------------------------------------------------------------+
input string             Expert_Title                 = EA_NAME;
ulong                    Expert_MagicNumber           = 53927483;
bool                     Expert_EveryTick             = false;

//--- Dashboard
input bool               ShowDashboard                = true;
input color              DashboardColor               = clrWhite;
input int                DashboardX                   = 10;
input int                DashboardY                   = 20;
input int                DashboardFontSize            = 10;

//--- Signal Thresholds
input int                Signal_ThresholdOpen         = 18;
input int                Signal_ThresholdClose        = 12;
input double             Signal_PriceLevel            = 0.0;
input int                Signal_Expiration            = 4;

//+------------------------------------------------------------------+
//| ATR Settings                                                     |
//+------------------------------------------------------------------+
input int                ATR_Period                   = 14;
input double             ATR_SL_Multiplier            = 1.5;
input double             ATR_TP_Multiplier            = 2.0;

//+------------------------------------------------------------------+
//| MA Filter Settings                                               |
//+------------------------------------------------------------------+
input int                Signal_0_MA_PeriodMA         = 200;
input int                Signal_0_MA_Shift            = 0;
input ENUM_MA_METHOD     Signal_0_MA_Method           = MODE_EMA;
input ENUM_APPLIED_PRICE Signal_0_MA_Applied         = PRICE_CLOSE;
input double             Signal_0_MA_Weight           = 0.12;

input int                Signal_1_MA_PeriodMA         = 50;
input int                Signal_1_MA_Shift            = 0;
input ENUM_MA_METHOD     Signal_1_MA_Method           = MODE_EMA;
input ENUM_APPLIED_PRICE Signal_1_MA_Applied         = PRICE_CLOSE;
input double             Signal_1_MA_Weight           = 0.12;

//+------------------------------------------------------------------+
//| Advanced Algorithm 1: RSI (Relative Strength Index)              |
//+------------------------------------------------------------------+
input int                RSI_Period                   = 14;
input double             RSI_Weight                   = 0.20;
input double             RSI_BuyLevel                 = 40;      // Buy when RSI > 40 (not oversold)
input double             RSI_SellLevel                = 60;      // Sell when RSI < 60 (not overbought)

//+------------------------------------------------------------------+
//| Advanced Algorithm 2: MACD (Moving Average Convergence Divergence)|
//+------------------------------------------------------------------+
input int                MACD_FastEMA                 = 12;
input int                MACD_SlowEMA                 = 26;
input int                MACD_Signal                  = 9;
input double             MACD_Weight                  = 0.20;

//+------------------------------------------------------------------+
//| Advanced Algorithm 3: CCI (Commodity Channel Index)              |
//+------------------------------------------------------------------+
input int                CCI_Period                   = 20;
input double             CCI_Weight                   = 0.16;
input double             CCI_BuyLevel                 = 0;       // Buy when CCI > 0
input double             CCI_SellLevel                = 0;       // Sell when CCI < 0

//+------------------------------------------------------------------+
//| Advanced Algorithm 4: Stochastic                                 |
//+------------------------------------------------------------------+
input int                Signal_Stoch_PeriodK         = 14;
input int                Signal_Stoch_PeriodD         = 3;
input int                Signal_Stoch_PeriodSlow      = 3;
input ENUM_STO_PRICE     Signal_Stoch_Applied         = STO_LOWHIGH;
input double             Signal_Stoch_Weight          = 0.20;

//--- Money Management
input double             Money_FixLot_Percent         = 10.0;
input double             Money_FixLot_Lots            = 0.1;

//--- Manual Control
input bool               EnableAutoTrade              = true;
input bool               EnableDebugLogging            = true;

//+------------------------------------------------------------------+
//| Global Objects                                                   |
//+------------------------------------------------------------------+
CTrade TradeExecutor;

// Statistics
int totalTrades = 0;
int winningTrades = 0;
int losingTrades = 0;
double totalProfit = 0.0;
double totalLoss = 0.0;
datetime lastTradeTime = 0;
int lastTradeType = 0;

// Signal tracking
int lastSignalStrength = 0;
TradeType lastSignalType = NO_TRADE;

// Indicator Handles
int atr_handle = INVALID_HANDLE;
int rsi_handle = INVALID_HANDLE;
int macd_handle = INVALID_HANDLE;
int cci_handle = INVALID_HANDLE;
int stoch_handle = INVALID_HANDLE;
int ma200_handle = INVALID_HANDLE;
int ma50_handle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Get Trade Comment                                                |
//+------------------------------------------------------------------+
string GetTradeComment() {
   string comment = TRADE_COMMENT;
   comment += " | v" + VERSION_NUMBER;
   comment += " | RSI:" + IntegerToString(RSI_Period);
   comment += " MACD:" + IntegerToString(MACD_FastEMA) + "/" + IntegerToString(MACD_SlowEMA);
   comment += " CCI:" + IntegerToString(CCI_Period);
   return comment;
}

//+------------------------------------------------------------------+
//| Get ATR Value                                                    |
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
//| Convert ATR to Points                                            |
//+------------------------------------------------------------------+
double ATRToPoints(double atr_value) {
   double point_value = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
   if(point_value == 0) point_value = 0.0001;
   
   return atr_value / point_value;
}

//+------------------------------------------------------------------+
//| ALGORITHM 1: RSI Signal Strength (0-100)                         |
//+------------------------------------------------------------------+
int GetRSISignalStrength() {
   double rsi_buffer[1];
   
   if(rsi_handle == INVALID_HANDLE) {
      rsi_handle = iRSI(Symbol(), Period(), RSI_Period, PRICE_CLOSE);
   }
   
   if(rsi_handle == INVALID_HANDLE || CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer) <= 0) {
      return 0;
   }
   
   double rsi_value = rsi_buffer[0];
   int strength = 0;
   
   // BUY: RSI between 40-60 (momentum building)
   if(rsi_value > RSI_BuyLevel && rsi_value < 70) {
      strength = (int)((rsi_value - RSI_BuyLevel) / (70 - RSI_BuyLevel) * 100);
      if(strength > 100) strength = 100;
   }
   
   // SELL: RSI between 40-60 (momentum building down)
   if(rsi_value < RSI_SellLevel && rsi_value > 30) {
      strength = (int)((RSI_SellLevel - rsi_value) / (RSI_SellLevel - 30) * 100);
      if(strength > 100) strength = 100;
   }
   
   return strength;
}

//+------------------------------------------------------------------+
//| ALGORITHM 2: MACD Signal Strength (0-100)                        |
//+------------------------------------------------------------------+
int GetMACDSignalStrength() {
   double macd_main[1], macd_signal[1];
   
   if(macd_handle == INVALID_HANDLE) {
      macd_handle = iMACD(Symbol(), Period(), MACD_FastEMA, MACD_SlowEMA, MACD_Signal, PRICE_CLOSE);
   }
   
   if(macd_handle == INVALID_HANDLE || 
      CopyBuffer(macd_handle, 0, 0, 1, macd_main) <= 0 ||
      CopyBuffer(macd_handle, 1, 0, 1, macd_signal) <= 0) {
      return 0;
   }
   
   double histogram = macd_main[0] - macd_signal[0];
   int strength = 0;
   
   // Bullish: MACD above Signal Line
   if(histogram > 0) {
      strength = (int)(MathMin(MathAbs(histogram) * 10000, 100));
   }
   // Bearish: MACD below Signal Line
   else {
      strength = (int)(MathMin(MathAbs(histogram) * 10000, 100));
   }
   
   return strength;
}

//+------------------------------------------------------------------+
//| ALGORITHM 3: CCI Signal Strength (0-100)                         |
//+------------------------------------------------------------------+
int GetCCISignalStrength() {
   double cci_buffer[1];
   
   if(cci_handle == INVALID_HANDLE) {
      cci_handle = iCCI(Symbol(), Period(), CCI_Period);
   }
   
   if(cci_handle == INVALID_HANDLE || CopyBuffer(cci_handle, 0, 0, 1, cci_buffer) <= 0) {
      return 0;
   }
   
   double cci_value = cci_buffer[0];
   int strength = 0;
   
   // Bullish: CCI above 0
   if(cci_value > 0) {
      strength = (int)(MathMin(cci_value / 100, 100));
   }
   // Bearish: CCI below 0
   else {
      strength = (int)(MathMin(MathAbs(cci_value) / 100, 100));
   }
   
   if(strength > 100) strength = 100;
   return strength;
}

//+------------------------------------------------------------------+
//| ALGORITHM 4: Stochastic Signal Strength (0-100)                  |
//+------------------------------------------------------------------+
int GetStochasticSignalStrength() {
   double stoch_k[1], stoch_d[1];
   
   if(stoch_handle == INVALID_HANDLE) {
      stoch_handle = iStochastic(Symbol(), Period(), Signal_Stoch_PeriodK, Signal_Stoch_PeriodD, Signal_Stoch_PeriodSlow, PRICE_CLOSE);
   }
   
   if(stoch_handle == INVALID_HANDLE || 
      CopyBuffer(stoch_handle, 0, 0, 1, stoch_k) <= 0 ||
      CopyBuffer(stoch_handle, 1, 0, 1, stoch_d) <= 0) {
      return 0;
   }
   
   int strength = 0;
   
   // Bullish: K > D and not overbought
   if(stoch_k[0] > stoch_d[0] && stoch_k[0] < 80) {
      strength = (int)((stoch_k[0] - stoch_d[0]) * 5);
      if(strength > 100) strength = 100;
   }
   // Bearish: K < D and not oversold
   else if(stoch_k[0] < stoch_d[0] && stoch_k[0] > 20) {
      strength = (int)((stoch_d[0] - stoch_k[0]) * 5);
      if(strength > 100) strength = 100;
   }
   
   return strength;
}

//+------------------------------------------------------------------+
//| MA Filter Check (Trend Confirmation)                             |
//+------------------------------------------------------------------+
int GetMAFilterStrength() {
   double ma200 = iMA(Symbol(), Period(), Signal_0_MA_PeriodMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ma50 = iMA(Symbol(), Period(), Signal_1_MA_PeriodMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double current_price = Close[0];
   
   int strength = 0;
   
   // Bullish: Price above both MAs
   if(current_price > ma50 && ma50 > ma200) {
      strength = 100;
   }
   // Bearish: Price below both MAs
   else if(current_price < ma50 && ma50 < ma200) {
      strength = 100;
   }
   
   return strength;
}

//+------------------------------------------------------------------+
//| Enhanced: Get BUY Signal Strength (All Algorithms Combined)       |
//+------------------------------------------------------------------+
int GetBuySignalStrength() {
   double ma200 = iMA(Symbol(), Period(), Signal_0_MA_PeriodMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ma50 = iMA(Symbol(), Period(), Signal_1_MA_PeriodMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   
   // Check trend first (must be bullish)
   if(Close[0] < ma50 || ma50 < ma200) {
      return 0;  // Not in bullish trend
   }
   
   // Get signals from all algorithms
   int rsi_signal = GetRSISignalStrength();
   int macd_signal = GetMACDSignalStrength();
   int cci_signal = GetCCISignalStrength();
   int stoch_signal = GetStochasticSignalStrength();
   
   // Weighted combination
   double weighted_strength = 
      (rsi_signal * RSI_Weight) +
      (macd_signal * MACD_Weight) +
      (cci_signal * CCI_Weight) +
      (stoch_signal * Signal_Stoch_Weight) +
      (GetMAFilterStrength() * (Signal_0_MA_Weight + Signal_1_MA_Weight));
   
   // Normalize to 0-100
   int final_strength = (int)MathMin(weighted_strength, 100);
   
   if(EnableDebugLogging && rsi_signal > 0) {
      printf("[%s BUY ANALYSIS] RSI:%d%% MACD:%d%% CCI:%d%% Stoch:%d%% → Combined:%d%%",
             EA_NAME, rsi_signal, macd_signal, cci_signal, stoch_signal, final_strength);
   }
   
   return final_strength;
}

//+------------------------------------------------------------------+
//| Enhanced: Get SELL Signal Strength (All Algorithms Combined)      |
//+------------------------------------------------------------------+
int GetSellSignalStrength() {
   double ma200 = iMA(Symbol(), Period(), Signal_0_MA_PeriodMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ma50 = iMA(Symbol(), Period(), Signal_1_MA_PeriodMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   
   // Check trend first (must be bearish)
   if(Close[0] > ma50 || ma50 > ma200) {
      return 0;  // Not in bearish trend
   }
   
   // Get signals from all algorithms (inverted for sell)
   double rsi_buffer[1];
   if(rsi_handle == INVALID_HANDLE) {
      rsi_handle = iRSI(Symbol(), Period(), RSI_Period, PRICE_CLOSE);
   }
   CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer);
   double rsi_value = rsi_buffer[0];
   int rsi_signal = (rsi_value < RSI_SellLevel && rsi_value > 30) ? 
                    (int)((RSI_SellLevel - rsi_value) / (RSI_SellLevel - 30) * 100) : 0;
   
   double macd_main[1], macd_signal[1];
   if(macd_handle == INVALID_HANDLE) {
      macd_handle = iMACD(Symbol(), Period(), MACD_FastEMA, MACD_SlowEMA, MACD_Signal, PRICE_CLOSE);
   }
   CopyBuffer(macd_handle, 0, 0, 1, macd_main);
   CopyBuffer(macd_handle, 1, 0, 1, macd_signal);
   double histogram = macd_main[0] - macd_signal[0];
   int macd_signal_val = (histogram < 0) ? (int)(MathMin(MathAbs(histogram) * 10000, 100)) : 0;
   
   double cci_buffer[1];
   if(cci_handle == INVALID_HANDLE) {
      cci_handle = iCCI(Symbol(), Period(), CCI_Period);
   }
   CopyBuffer(cci_handle, 0, 0, 1, cci_buffer);
   double cci_value = cci_buffer[0];
   int cci_signal_val = (cci_value < 0) ? (int)(MathMin(MathAbs(cci_value) / 100, 100)) : 0;
   
   double stoch_k[1], stoch_d[1];
   if(stoch_handle == INVALID_HANDLE) {
      stoch_handle = iStochastic(Symbol(), Period(), Signal_Stoch_PeriodK, Signal_Stoch_PeriodD, Signal_Stoch_PeriodSlow, PRICE_CLOSE);
   }
   CopyBuffer(stoch_handle, 0, 0, 1, stoch_k);
   CopyBuffer(stoch_handle, 1, 0, 1, stoch_d);
   int stoch_signal_val = (stoch_k[0] < stoch_d[0] && stoch_k[0] > 20) ? 
                          (int)((stoch_d[0] - stoch_k[0]) * 5) : 0;
   
   // Weighted combination
   double weighted_strength = 
      (rsi_signal * RSI_Weight) +
      (macd_signal_val * MACD_Weight) +
      (cci_signal_val * CCI_Weight) +
      (stoch_signal_val * Signal_Stoch_Weight) +
      (GetMAFilterStrength() * (Signal_0_MA_Weight + Signal_1_MA_Weight));
   
   int final_strength = (int)MathMin(weighted_strength, 100);
   
   if(EnableDebugLogging && rsi_signal > 0) {
      printf("[%s SELL ANALYSIS] RSI:%d%% MACD:%d%% CCI:%d%% Stoch:%d%% → Combined:%d%%",
             EA_NAME, rsi_signal, macd_signal_val, cci_signal_val, stoch_signal_val, final_strength);
   }
   
   return final_strength;
}

//+------------------------------------------------------------------+
//| Check Trade Signal                                               |
//+------------------------------------------------------------------+
TradeType CheckTradeSignal() {
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
         printf("[%s] ✓ BUY Signal Confirmed: Strength=%d%% (Threshold=%d%%)", 
                EA_NAME, buy_strength, Signal_ThresholdOpen);
      }
      return BUY_TRADE;
   }
   
   // SELL Signal
   if(sell_strength >= Signal_ThresholdOpen && sell_strength > buy_strength) {
      lastSignalType = SELL_TRADE;
      if(EnableDebugLogging) {
         printf("[%s] ✓ SELL Signal Confirmed: Strength=%d%% (Threshold=%d%%)", 
                EA_NAME, sell_strength, Signal_ThresholdOpen);
      }
      return SELL_TRADE;
   }
   
   return NO_TRADE;
}

//+------------------------------------------------------------------+
//| Execute BUY Trade                                                |
//+------------------------------------------------------------------+
bool ExecuteBuyTrade() {
   if(!EnableAutoTrade) return false;
   
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double atr = GetATR();
   double atr_points = ATRToPoints(atr);
   
   double sl = ask - (atr_points * ATR_SL_Multiplier) * Point();
   double tp = ask + (atr_points * ATR_TP_Multiplier) * Point();
   double lot = Money_FixLot_Lots;
   
   bool result = TradeExecutor.Buy(lot, Symbol(), ask, sl, tp, GetTradeComment());
   
   if(result) {
      lastTradeTime = TimeCurrent();
      lastTradeType = 1;
      if(EnableDebugLogging) {
         printf("[%s] 🟢 BUY Executed: Price=%.5f | ATR=%.5f | SL=%.5f | TP=%.5f | Lot=%.2f", 
                EA_NAME, ask, atr, sl, tp, lot);
      }
   } else {
      if(EnableDebugLogging) {
         printf("[%s] ❌ BUY Failed: %s", EA_NAME, TradeExecutor.ResultComment());
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Execute SELL Trade                                               |
//+------------------------------------------------------------------+
bool ExecuteSellTrade() {
   if(!EnableAutoTrade) return false;
   
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double atr = GetATR();
   double atr_points = ATRToPoints(atr);
   
   double sl = bid + (atr_points * ATR_SL_Multiplier) * Point();
   double tp = bid - (atr_points * ATR_TP_Multiplier) * Point();
   double lot = Money_FixLot_Lots;
   
   bool result = TradeExecutor.Sell(lot, Symbol(), bid, sl, tp, GetTradeComment());
   
   if(result) {
      lastTradeTime = TimeCurrent();
      lastTradeType = -1;
      if(EnableDebugLogging) {
         printf("[%s] 🔴 SELL Executed: Price=%.5f | ATR=%.5f | SL=%.5f | TP=%.5f | Lot=%.2f", 
                EA_NAME, bid, atr, sl, tp, lot);
      }
   } else {
      if(EnableDebugLogging) {
         printf("[%s] ❌ SELL Failed: %s", EA_NAME, TradeExecutor.ResultComment());
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Update Trading Statistics                                        |
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
//| Draw Dashboard                                                   |
//+------------------------------------------------------------------+
void DrawDashboard() {
   if(!ShowDashboard) return;
   
   UpdateTradingStats();
   
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
   double atr = GetATR();
   double atr_points = ATRToPoints(atr);
   
   double rsi_buffer[1];
   if(rsi_handle != INVALID_HANDLE) CopyBuffer(rsi_handle, 0, 0, 1, rsi_buffer);
   
   double macd_main[1], macd_signal[1];
   if(macd_handle != INVALID_HANDLE) {
      CopyBuffer(macd_handle, 0, 0, 1, macd_main);
      CopyBuffer(macd_handle, 1, 0, 1, macd_signal);
   }
   
   double cci_buffer[1];
   if(cci_handle != INVALID_HANDLE) CopyBuffer(cci_handle, 0, 0, 1, cci_buffer);
   
   double stoch_k[1], stoch_d[1];
   if(stoch_handle != INVALID_HANDLE) {
      CopyBuffer(stoch_handle, 0, 0, 1, stoch_k);
      CopyBuffer(stoch_handle, 1, 0, 1, stoch_d);
   }
   
   string dashboardText = "";
   dashboardText += "╔═════════════════════════════════════════╗\n";
   dashboardText += "║  " + EA_NAME + " v" + VERSION_NUMBER + " - ADVANCED DASHBOARD  ║\n";
   dashboardText += "╠═════════════════════════════════════════╣\n";
   dashboardText += "║ Symbol: " + Symbol() + " | TF: " + IntegerToString(Period()) + "m\n";
   dashboardText += "║ Bid: " + DoubleToString(bid, 5) + " | Ask: " + DoubleToString(ask, 5) + "\n";
   dashboardText += "╠═════════════════════════════════════════╣\n";
   dashboardText += "║ ADVANCED ALGORITHMS\n";
   dashboardText += "║ RSI(" + IntegerToString(RSI_Period) + "): " + DoubleToString(rsi_buffer[0], 2) + " | MACD Hist: " + DoubleToString(macd_main[0] - macd_signal[0], 5) + "\n";
   dashboardText += "║ CCI(" + IntegerToString(CCI_Period) + "): " + DoubleToString(cci_buffer[0], 2) + " | Stoch K: " + DoubleToString(stoch_k[0], 2) + " D: " + DoubleToString(stoch_d[0], 2) + "\n";
   dashboardText += "╠═════════════════════════════════════════╣\n";
   dashboardText += "║ CURRENT SIGNALS\n";
   dashboardText += "║ Buy Strength: " + IntegerToString(GetBuySignalStrength()) + "%\n";
   dashboardText += "║ Sell Strength: " + IntegerToString(GetSellSignalStrength()) + "%\n";
   dashboardText += "║ Threshold: " + IntegerToString(Signal_ThresholdOpen) + "%\n";
   dashboardText += "╠═════════════════════════════════════════╣\n";
   dashboardText += "║ ATR SETTINGS\n";
   dashboardText += "║ ATR: " + DoubleToString(atr, 5) + " (" + DoubleToString(atr_points, 0) + " pts)\n";
   dashboardText += "║ SL: " + DoubleToString(atr_points * ATR_SL_Multiplier, 0) + "pts | TP: " + DoubleToString(atr_points * ATR_TP_Multiplier, 0) + "pts\n";
   dashboardText += "╠═════════════════════════════════════════╣\n";
   dashboardText += "║ STATISTICS\n";
   dashboardText += "║ Total: " + IntegerToString(totalTrades) + " | Wins: " + IntegerToString(winningTrades) + " | Loss: " + IntegerToString(losingTrades) + "\n";
   
   double winRate = (totalTrades > 0) ? (double)winningTrades / totalTrades * 100 : 0;
   dashboardText += "║ Win Rate: " + DoubleToString(winRate, 1) + "% | P&L: " + DoubleToString(totalProfit, 2) + "\n";
   dashboardText += "╠═════════════════════════════════════════╣\n";
   dashboardText += "║ STATUS: " + (PositionsTotal() > 0 ? "🟢 IN TRADE" : "🔴 WAITING") + " | AutoTrade: " + (EnableAutoTrade ? "ON" : "OFF") + "\n";
   dashboardText += "╚═════════════════════════════════════════╝\n";
   
   Comment(dashboardText);
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit() {
   // Initialize Trade executor
   TradeExecutor.SetExpertMagicNumber(Expert_MagicNumber);
   TradeExecutor.LogLevel(LOG_LEVEL_ERRORS);
   
   // Initialize indicators
   atr_handle = iATR(Symbol(), Period(), ATR_Period);
   rsi_handle = iRSI(Symbol(), Period(), RSI_Period, PRICE_CLOSE);
   macd_handle = iMACD(Symbol(), Period(), MACD_FastEMA, MACD_SlowEMA, MACD_Signal, PRICE_CLOSE);
   cci_handle = iCCI(Symbol(), Period(), CCI_Period);
   stoch_handle = iStochastic(Symbol(), Period(), Signal_Stoch_PeriodK, Signal_Stoch_PeriodD, Signal_Stoch_PeriodSlow, PRICE_CLOSE);
   
   if(atr_handle == INVALID_HANDLE || rsi_handle == INVALID_HANDLE || macd_handle == INVALID_HANDLE || 
      cci_handle == INVALID_HANDLE || stoch_handle == INVALID_HANDLE) {
      printf("[%s] ERROR: Failed to initialize indicators", EA_NAME);
      return(INIT_FAILED);
   }
   
   printf("\n╔═════════════════════════════════════════╗");
   printf("\n║  " + EA_NAME + " v" + VERSION_NUMBER + " - INITIALIZED");
   printf("\n║  Advanced Algorithms Enabled:");
   printf("\n║  ✓ RSI(14) | ✓ MACD(12,26,9)");
   printf("\n║  ✓ CCI(20) | ✓ Stochastic(14,3,3)");
   printf("\n║  ✓ ATR-based Dynamic SL/TP");
   printf("\n║  Magic: %d | AutoTrade: %s", Expert_MagicNumber, EnableAutoTrade ? "ON" : "OFF");
   printf("\n╚═════════════════════════════════════════╝\n");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
   if(rsi_handle != INVALID_HANDLE) IndicatorRelease(rsi_handle);
   if(macd_handle != INVALID_HANDLE) IndicatorRelease(macd_handle);
   if(cci_handle != INVALID_HANDLE) IndicatorRelease(cci_handle);
   if(stoch_handle != INVALID_HANDLE) IndicatorRelease(stoch_handle);
   
   Comment("");
   printf("[%s] Deinitialized (Reason: %d)", EA_NAME, reason);
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick() {
   DrawDashboard();
   
   TradeType signal = CheckTradeSignal();
   
   if(signal == BUY_TRADE) {
      ExecuteBuyTrade();
   } else if(signal == SELL_TRADE) {
      ExecuteSellTrade();
   }
}

//+------------------------------------------------------------------+
//| OnTrade                                                          |
//+------------------------------------------------------------------+
void OnTrade() {
   UpdateTradingStats();
   
   if(EnableDebugLogging) {
      printf("[%s] Trade Event - Total: %d, Profit: %.2f", 
             EA_NAME, totalTrades, totalProfit);
   }
}

//+------------------------------------------------------------------+
