//+------------------------------------------------------------------+
//|                  EA31337 - multi-strategy advanced trading robot |
//|                       Copyright 2016-2020, 31337 Investments Ltd |
//|                                       https://github.com/EA31337 |
//+------------------------------------------------------------------+

/**
 * @file
 * Implements BearsPower strategy based on the Bears Power indicator.
 */

// Includes.
#include <EA31337-classes/Indicators/Indi_BearsPower.mqh>
#include <EA31337-classes/Strategy.mqh>

// User input params.
INPUT string __BearsPower_Parameters__ = "-- BearsPower strategy params --";  // >>> BEARS POWER <<<
INPUT int BearsPower_Period = 13;                                             // Period
INPUT ENUM_APPLIED_PRICE BearsPower_Applied_Price = PRICE_CLOSE;              // Applied Price
INPUT int BearsPower_Shift = 0;                         // Shift (relative to the current bar, 0 - default)
INPUT int BearsPower_SignalOpenMethod = 0;              // Signal open method (0-
INPUT double BearsPower_SignalOpenLevel = 0.00000000;   // Signal open level
INPUT int BearsPower_SignalOpenFilterMethod = 0;        // Signal filter method
INPUT int BearsPower_SignalOpenBoostMethod = 0;         // Signal boost method
INPUT int BearsPower_SignalCloseMethod = 0;             // Signal close method
INPUT double BearsPower_SignalCloseLevel = 0.00000000;  // Signal close level
INPUT int BearsPower_PriceLimitMethod = 0;              // Price limit method
INPUT double BearsPower_PriceLimitLevel = 0;            // Price limit level
INPUT double BearsPower_MaxSpread = 6.0;                // Max spread to trade (pips)

// Struct to define strategy parameters to override.
struct Stg_BearsPower_Params : StgParams {
  unsigned int BearsPower_Period;
  ENUM_APPLIED_PRICE BearsPower_Applied_Price;
  int BearsPower_Shift;
  int BearsPower_SignalOpenMethod;
  double BearsPower_SignalOpenLevel;
  int BearsPower_SignalOpenFilterMethod;
  int BearsPower_SignalOpenBoostMethod;
  int BearsPower_SignalCloseMethod;
  double BearsPower_SignalCloseLevel;
  double BearsPower_PriceLimitLevel;
  int BearsPower_PriceLimitMethod;
  double BearsPower_MaxSpread;

  // Constructor: Set default param values.
  Stg_BearsPower_Params()
      : BearsPower_Period(::BearsPower_Period),
        BearsPower_Applied_Price(::BearsPower_Applied_Price),
        BearsPower_Shift(::BearsPower_Shift),
        BearsPower_SignalOpenMethod(::BearsPower_SignalOpenMethod),
        BearsPower_SignalOpenLevel(::BearsPower_SignalOpenLevel),
        BearsPower_SignalOpenFilterMethod(::BearsPower_SignalOpenFilterMethod),
        BearsPower_SignalOpenBoostMethod(::BearsPower_SignalOpenBoostMethod),
        BearsPower_SignalCloseMethod(::BearsPower_SignalCloseMethod),
        BearsPower_SignalCloseLevel(::BearsPower_SignalCloseLevel),
        BearsPower_PriceLimitMethod(::BearsPower_PriceLimitMethod),
        BearsPower_PriceLimitLevel(::BearsPower_PriceLimitLevel),
        BearsPower_MaxSpread(::BearsPower_MaxSpread) {}
};

// Loads pair specific param values.
#include "sets/EURUSD_H1.h"
#include "sets/EURUSD_H4.h"
#include "sets/EURUSD_M1.h"
#include "sets/EURUSD_M15.h"
#include "sets/EURUSD_M30.h"
#include "sets/EURUSD_M5.h"

class Stg_BearsPower : public Strategy {
 public:
  Stg_BearsPower(StgParams &_params, string _name) : Strategy(_params, _name) {}

  static Stg_BearsPower *Init(ENUM_TIMEFRAMES _tf = NULL, long _magic_no = NULL, ENUM_LOG_LEVEL _log_level = V_INFO) {
    // Initialize strategy initial values.
    Stg_BearsPower_Params _params;
    if (!Terminal::IsOptimization()) {
      SetParamsByTf<Stg_BearsPower_Params>(_params, _tf, stg_bears_m1, stg_bears_m5, stg_bears_m15, stg_bears_m30,
                                           stg_bears_h1, stg_bears_h4, stg_bears_h4);
    }
    // Initialize strategy parameters.
    BearsPowerParams bp_params(_params.BearsPower_Period, _params.BearsPower_Applied_Price);
    bp_params.SetTf(_tf);
    StgParams sparams(new Trade(_tf, _Symbol), new Indi_BearsPower(bp_params), NULL, NULL);
    sparams.logger.SetLevel(_log_level);
    sparams.SetMagicNo(_magic_no);
    sparams.SetSignals(_params.BearsPower_SignalOpenMethod, _params.BearsPower_SignalOpenMethod,
                       _params.BearsPower_SignalOpenFilterMethod, _params.BearsPower_SignalOpenBoostMethod,
                       _params.BearsPower_SignalCloseMethod, _params.BearsPower_SignalCloseMethod);
    sparams.SetMaxSpread(_params.BearsPower_MaxSpread);
    // Initialize strategy instance.
    Strategy *_strat = new Stg_BearsPower(sparams, "BearsPower");
    return _strat;
  }

  /**
   * Check strategy's opening signal.
   */
  bool SignalOpen(ENUM_ORDER_TYPE _cmd, int _method = 0, double _level = 0.0) {
    Chart *_chart = Chart();
    Indicator *_indi = Data();
    bool _is_valid = _indi[CURR].IsValid() && _indi[PREV].IsValid() && _indi[PPREV].IsValid();
    bool _result = _is_valid;
    if (!_result) {
      // Returns false when indicator data is not valid.
      return false;
    }
    double level = _level * Chart().GetPipSize();
    switch (_cmd) {
      case ORDER_TYPE_BUY:
        // The histogram is above zero level.
        // Fall of histogram, which is above zero, indicates that while the bulls prevail on the market,
        // their strength begins to weaken and the bears gradually increase their pressure.
        _result &= _indi[CURR].value[0] > _level;
        if (_method != 0) {
          if (METHOD(_method, 0)) _result &= _indi[PREV].value[0] < _indi[PPREV].value[0]; // ... 2 consecutive columns are red.
          if (METHOD(_method, 1)) _result &= _indi[PPREV].value[0] < _indi[3].value[0]; // ... 3 consecutive columns are red.
          if (METHOD(_method, 2)) _result &= _indi[3].value[0] < _indi[4].value[0]; // ... 4 consecutive columns are red.
          if (METHOD(_method, 3)) _result &= _indi[PREV].value[0] > _indi[PPREV].value[0]; // ... 2 consecutive columns are green.
          if (METHOD(_method, 4)) _result &= _indi[PPREV].value[0] > _indi[3].value[0]; // ... 3 consecutive columns are green.
          // When histogram passes through zero level from bottom up,
          // bears have lost control over the market and bulls increase pressure.
          if (METHOD(_method, 5)) _result &= _indi[3].value[0] < _indi[4].value[0]; // ... 4 consecutive columns are green.
        }
        break;
      case ORDER_TYPE_SELL:
        // Strong bearish trend - the histogram is located below the central line.
        _result &= _indi[CURR].value[0] < _level;
        if (_method != 0) {
          // When histogram is below zero level, but with the rays pointing upwards (upward trend),
          // then we can assume that, in spite of still bearish sentiment in the market, their strength begins to weaken.
          if (METHOD(_method, 0)) _result &= _indi[PREV].value[0] > _indi[PPREV].value[0]; // ... 2 consecutive columns are green.
          if (METHOD(_method, 1)) _result &= _indi[PPREV].value[0] > _indi[3].value[0]; // ... 3 consecutive columns are green.
          if (METHOD(_method, 2)) _result &= _indi[3].value[0] > _indi[4].value[0]; // ... 4 consecutive columns are green.
          if (METHOD(_method, 3)) _result &= _indi[PREV].value[0] < _indi[PPREV].value[0]; // ... 2 consecutive columns are red.
          if (METHOD(_method, 4)) _result &= _indi[PPREV].value[0] < _indi[3].value[0]; // ... 3 consecutive columns are red.
          if (METHOD(_method, 5)) _result &= _indi[3].value[0] > _indi[4].value[0]; // ... 4 consecutive columns are red.
        }
        break;
    }
    return _result;
  }

  /**
   * Check strategy's opening signal additional filter.
   */
  bool SignalOpenFilter(ENUM_ORDER_TYPE _cmd, int _method = 0) {
    bool _result = true;
    if (_method != 0) {
      // if (METHOD(_method, 0)) _result &= Trade().IsTrend(_cmd);
      // if (METHOD(_method, 1)) _result &= Trade().IsPivot(_cmd);
      // if (METHOD(_method, 2)) _result &= Trade().IsPeakHours(_cmd);
      // if (METHOD(_method, 3)) _result &= Trade().IsRoundNumber(_cmd);
      // if (METHOD(_method, 4)) _result &= Trade().IsHedging(_cmd);
      // if (METHOD(_method, 5)) _result &= Trade().IsPeakBar(_cmd);
    }
    return _result;
  }

  /**
   * Gets strategy's lot size boost (when enabled).
   */
  double SignalOpenBoost(ENUM_ORDER_TYPE _cmd, int _method = 0) {
    bool _result = 1.0;
    if (_method != 0) {
      // if (METHOD(_method, 0)) if (Trade().IsTrend(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 1)) if (Trade().IsPivot(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 2)) if (Trade().IsPeakHours(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 3)) if (Trade().IsRoundNumber(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 4)) if (Trade().IsHedging(_cmd)) _result *= 1.1;
      // if (METHOD(_method, 5)) if (Trade().IsPeakBar(_cmd)) _result *= 1.1;
    }
    return _result;
  }

  /**
   * Check strategy's closing signal.
   */
  bool SignalClose(ENUM_ORDER_TYPE _cmd, int _method = 0, double _level = 0.0) {
    return SignalOpen(Order::NegateOrderType(_cmd), _method, _level);
  }

  /**
   * Gets price limit value for profit take or stop loss.
   */
  double PriceLimit(ENUM_ORDER_TYPE _cmd, ENUM_ORDER_TYPE_VALUE _mode, int _method = 0, double _level = 0.0) {
    double _trail = _level * Market().GetPipSize();
    int _direction = Order::OrderDirection(_cmd, _mode);
    double _default_value = Market().GetCloseOffer(_cmd) + _trail * _method * _direction;
    double _result = _default_value;
    switch (_method) {
      case 0: {
        // @todo
      }
    }
    return _result;
  }
};