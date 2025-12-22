// lib/modules/game/components/ai/learning_ai_system.dart

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// 🧠 AI Learning System - Snakes adapt to player behavior
///
/// This system tracks player patterns and adjusts AI behavior accordingly:
/// - Learns player's aggression level
/// - Adapts to player's risk-taking behavior
/// - Recognizes player's favorite strategies
/// - Adjusts difficulty dynamically

// ============================================================================
// PLAYER PATTERN TRACKER
// ============================================================================

class PlayerPattern {
  // Combat patterns
  double aggressivenessScore = 0.5; // 0 = passive, 1 = very aggressive
  double riskTakingScore = 0.5; // 0 = cautious, 1 = reckless
  double boostUsageScore = 0.5; // 0 = rare, 1 = frequent

  // Movement patterns
  double movementSpeedAvg = 0.0;
  double directionChangeFrequency = 0.0;
  List<Vector2> recentPositions = [];

  // Food collection patterns
  double foodPriorityScore = 0.7; // 0 = combat focus, 1 = food focus
  int foodCollectedCount = 0;
  int killCount = 0;

  // Strategic patterns
  double retreatTendency = 0.5; // How often player retreats when threatened
  double chasePersistence = 0.5; // How long player chases targets
  Vector2? favoriteArea; // Area player spends most time in

  // Learning rate - how quickly AI adapts (higher = faster learning)
  static const double learningRate = 0.09;

  // Time tracking
  double timeSinceLastUpdate = 0.0;
  static const double updateInterval = 2.0; // Update every 2 seconds

  void reset() {
    aggressivenessScore = 0.5;
    riskTakingScore = 0.5;
    boostUsageScore = 0.5;
    movementSpeedAvg = 0.0;
    directionChangeFrequency = 0.0;
    recentPositions.clear();
    foodPriorityScore = 0.5;
    foodCollectedCount = 0;
    killCount = 0;
    retreatTendency = 0.5;
    chasePersistence = 0.5;
    favoriteArea = null;
    timeSinceLastUpdate = 0.0;
  }
}

// ============================================================================
// LEARNING MEMORY - Stores what AI has learned
// ============================================================================

class LearningMemory {
  // Successful strategies against this player
  Map<String, double> strategySuccessRates = {
    'aggressive_chase': 0.5,
    'defensive_flee': 0.5,
    'food_competition': 0.5,
    'ambush': 0.5,
    'circle_trap': 0.5,
    'boost_intercept': 0.5,
  };

  // Dangerous situations to avoid
  List<String> knownDangers = [];

  // Effective counter-tactics
  Map<String, int> effectiveTactics = {};

  // Player weakness areas
  List<String> exploitableWeaknesses = [];

  void recordStrategySuccess(String strategy, bool success) {
    final currentRate = strategySuccessRates[strategy] ?? 0.5;
    final adjustment = success ? 0.1 : -0.1;
    strategySuccessRates[strategy] = (currentRate + adjustment).clamp(0.0, 1.0);
  }

  void recordDanger(String dangerType) {
    if (!knownDangers.contains(dangerType)) {
      knownDangers.add(dangerType);
    }
  }

  void recordEffectiveTactic(String tactic) {
    effectiveTactics[tactic] = (effectiveTactics[tactic] ?? 0) + 1;
  }

  String getMostEffectiveStrategy() {
    if (strategySuccessRates.isEmpty) return 'aggressive_chase';
    return strategySuccessRates.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}

// ============================================================================
// ADAPTIVE BEHAVIOR CONTROLLER
// ============================================================================

class AdaptiveBehavior {
  final PlayerPattern playerPattern;
  final LearningMemory memory;

  // Adaptation levels (0-1, where 0.5 is baseline)
  double adaptedAggression = 0.5;
  double adaptedCaution = 0.5;
  double adaptedFoodFocus = 0.5;
  double adaptedBoostUsage = 0.5;

  // Counter-strategy modifiers
  double counterAggressionBonus = 0.0;
  double counterSpeedBonus = 0.0;

  AdaptiveBehavior({
    required this.playerPattern,
    required this.memory,
  });

  /// Update adaptive behavior based on learned patterns
  void updateAdaptation() {
    // Counter player's aggression
    if (playerPattern.aggressivenessScore > 0.7) {
      // Player is aggressive - become more cautious OR match aggression
      if (memory.strategySuccessRates['defensive_flee']! > 0.6) {
        adaptedCaution = 0.7; // Defensive works, stay cautious
        adaptedAggression = 0.3;
      } else {
        adaptedAggression = 0.8; // Match their aggression
        adaptedCaution = 0.4;
      }
    } else if (playerPattern.aggressivenessScore < 0.3) {
      // Player is passive - exploit with aggression
      adaptedAggression = 0.8;
      adaptedCaution = 0.3;
      memory.exploitableWeaknesses.add('passive_playstyle');
    }

    // Adapt to player's risk-taking
    if (playerPattern.riskTakingScore > 0.7) {
      // Player takes risks - set traps and ambushes
      adaptedCaution = 0.7; // Stay safe, let them take risks
      counterAggressionBonus = 0.2; // Punish their mistakes
    } else {
      // Player is cautious - need to be proactive
      adaptedAggression = 0.6;
      adaptedFoodFocus = 0.7; // Compete for resources
    }

    // Adapt to boost usage
    if (playerPattern.boostUsageScore > 0.7) {
      // Player boosts a lot - conserve energy and predict paths
      adaptedBoostUsage = 0.4; // Use less boost
      counterSpeedBonus = 0.1; // Slight speed increase for positioning
    } else {
      // Player rarely boosts - use boost for advantage
      adaptedBoostUsage = 0.7;
    }

    // Adapt to food priority
    if (playerPattern.foodPriorityScore > 0.7) {
      // Player focuses on food - compete aggressively for it
      adaptedFoodFocus = 0.9;
      adaptedAggression = 0.6;
      memory.recordEffectiveTactic('food_competition');
    } else {
      // Player focuses on combat - either avoid or match
      if (playerPattern.killCount > 5) {
        adaptedCaution = 0.7; // They're dangerous
        adaptedFoodFocus = 0.8; // Focus on growth
      }
    }

    // Learn from retreat patterns
    if (playerPattern.retreatTendency > 0.6) {
      // Player retreats often - pursue aggressively
      adaptedAggression = 0.8;
      memory.exploitableWeaknesses.add('retreats_under_pressure');
    }
  }

  /// Get adapted personality modifier for specific trait
  double getAdaptedTrait(String trait) {
    switch (trait) {
      case 'aggression':
        return adaptedAggression + counterAggressionBonus;
      case 'caution':
        return adaptedCaution;
      case 'greed':
        return adaptedFoodFocus;
      case 'boostPreference':
        return adaptedBoostUsage;
      default:
        return 0.5;
    }
  }
}

// ============================================================================
// PLAYER BEHAVIOR ANALYZER
// ============================================================================

class PlayerBehaviorAnalyzer {
  final PlayerPattern pattern = PlayerPattern();
  final LearningMemory memory = LearningMemory();
  late final AdaptiveBehavior adaptiveBehavior;

  // Tracking variables
  Vector2 _lastPlayerPosition = Vector2.zero();
  double _lastPlayerAngle = 0.0;
  bool _wasBoostingLastFrame = false;
  int _lastFoodCount = 0;
  int _lastKillCount = 0;

  // Combat tracking
  bool _inCombat = false;
  double _combatStartTime = 0.0;
  bool _playerFledFromCombat = false;

  // Learning statistics
  int _totalInteractions = 0;
  int _successfulPredictions = 0;

  PlayerBehaviorAnalyzer() {
    adaptiveBehavior = AdaptiveBehavior(
      playerPattern: pattern,
      memory: memory,
    );
  }

  /// Main analysis update - call every frame
  void analyze(
      Vector2 playerPosition,
      double playerAngle,
      bool isBoosting,
      int foodCount,
      int killCount,
      List<Vector2> nearbyAiSnakes,
      double dt,
      ) {
    pattern.timeSinceLastUpdate += dt;

    // Update position history
    pattern.recentPositions.add(playerPosition.clone());
    if (pattern.recentPositions.length > 100) {
      pattern.recentPositions.removeAt(0);
    }

    // Analyze movement speed
    final distance = playerPosition.distanceTo(_lastPlayerPosition);
    pattern.movementSpeedAvg = pattern.movementSpeedAvg * 0.95 + (distance / dt) * 0.05;

    // Analyze direction changes
    final angleDiff = (_lastPlayerAngle - playerAngle).abs();
    if (angleDiff > 0.5) {
      pattern.directionChangeFrequency =
          pattern.directionChangeFrequency * 0.98 + 0.02;
    } else {
      pattern.directionChangeFrequency *= 0.99;
    }

    // Analyze boost usage
    if (isBoosting && !_wasBoostingLastFrame) {
      // Player started boosting
      pattern.boostUsageScore = pattern.boostUsageScore * 0.95 + 0.05;
    }

    // Analyze food collection
    if (foodCount > _lastFoodCount) {
      pattern.foodCollectedCount++;
      _updateFoodPriority();
    }

    // Analyze kill behavior
    if (killCount > _lastKillCount) {
      pattern.killCount++;
      _updateAggressiveness(true);
    }

    // Combat behavior analysis
    _analyzeCombatBehavior(playerPosition, nearbyAiSnakes);

    // Risk-taking analysis
    _analyzeRiskTaking(playerPosition, nearbyAiSnakes);

    // Periodic comprehensive update
    if (pattern.timeSinceLastUpdate >= PlayerPattern.updateInterval) {
      _performComprehensiveAnalysis();
      adaptiveBehavior.updateAdaptation();
      pattern.timeSinceLastUpdate = 0.0;

      _logLearningProgress();
    }

    // Update tracking variables
    _lastPlayerPosition = playerPosition.clone();
    _lastPlayerAngle = playerAngle;
    _wasBoostingLastFrame = isBoosting;
    _lastFoodCount = foodCount;
    _lastKillCount = killCount;
  }

  void _analyzeCombatBehavior(Vector2 playerPos, List<Vector2> nearbyAiSnakes) {
    final hasNearbyThreats = nearbyAiSnakes.isNotEmpty;

    if (hasNearbyThreats && !_inCombat) {
      // Combat started
      _inCombat = true;
      _combatStartTime = DateTime.now().millisecondsSinceEpoch / 1000.0;
      _playerFledFromCombat = false;
    } else if (!hasNearbyThreats && _inCombat) {
      // Combat ended
      final combatDuration = (DateTime.now().millisecondsSinceEpoch / 1000.0) - _combatStartTime;

      if (combatDuration < 2.0 && !_playerFledFromCombat) {
        // Quick escape = likely fled
        _playerFledFromCombat = true;
        pattern.retreatTendency = pattern.retreatTendency * 0.9 + 0.1;
      } else if (combatDuration > 5.0) {
        // Long engagement = persistent
        pattern.chasePersistence = pattern.chasePersistence * 0.9 + 0.1;
      }

      _inCombat = false;
    }
  }

  void _analyzeRiskTaking(Vector2 playerPos, List<Vector2> nearbyAiSnakes) {
    if (nearbyAiSnakes.isEmpty) return;

    // Check if player is taking risks by going near danger
    final closestThreatDist = nearbyAiSnakes
        .map((pos) => playerPos.distanceTo(pos))
        .reduce((a, b) => a < b ? a : b);

    if (closestThreatDist < 100) {
      // Very close to danger
      pattern.riskTakingScore = pattern.riskTakingScore * 0.95 + 0.05;

      if (_wasBoostingLastFrame) {
        // Boosting near danger = very risky
        pattern.riskTakingScore = pattern.riskTakingScore * 0.9 + 0.1;
      }
    } else if (closestThreatDist > 300) {
      // Playing it safe
      pattern.riskTakingScore *= 0.99;
    }
  }

  void _updateAggressiveness(bool killedTarget) {
    if (killedTarget) {
      // Successfully killed - increase aggression score
      pattern.aggressivenessScore = pattern.aggressivenessScore * 0.9 + 0.1;
      memory.recordStrategySuccess('aggressive_chase', true);
    }
  }

  void _updateFoodPriority() {
    // Compare food collected vs kills to determine priority
    final totalActions = pattern.foodCollectedCount + pattern.killCount;
    if (totalActions > 0) {
      pattern.foodPriorityScore = pattern.foodCollectedCount / totalActions;
    }
  }

  void _performComprehensiveAnalysis() {
    // Calculate favorite area
    if (pattern.recentPositions.length > 20) {
      final avgX = pattern.recentPositions.map((p) => p.x).reduce((a, b) => a + b) /
          pattern.recentPositions.length;
      final avgY = pattern.recentPositions.map((p) => p.y).reduce((a, b) => a + b) /
          pattern.recentPositions.length;
      pattern.favoriteArea = Vector2(avgX, avgY);
    }

    // Update learning statistics
    _totalInteractions++;

    // Identify exploitable patterns
    if (pattern.retreatTendency > 0.7) {
      if (!memory.exploitableWeaknesses.contains('frequent_retreater')) {
        memory.exploitableWeaknesses.add('frequent_retreater');
      }
    }

    if (pattern.directionChangeFrequency > 0.3) {
      if (!memory.exploitableWeaknesses.contains('erratic_movement')) {
        memory.exploitableWeaknesses.add('erratic_movement');
      }
    }

    if (pattern.boostUsageScore > 0.8) {
      if (!memory.exploitableWeaknesses.contains('boost_dependent')) {
        memory.exploitableWeaknesses.add('boost_dependent');
      }
    }
  }

  void _logLearningProgress() {
    // print('🧠 AI LEARNING UPDATE:');
    // print('   Player Aggression: ${(pattern.aggressivenessScore * 100).toInt()}%');
    // print('   Risk Taking: ${(pattern.riskTakingScore * 100).toInt()}%');
    // print('   Food Priority: ${(pattern.foodPriorityScore * 100).toInt()}%');
    // print('   Retreat Tendency: ${(pattern.retreatTendency * 100).toInt()}%');
    // print('   Kills: ${pattern.killCount} | Food: ${pattern.foodCollectedCount}');
    // print('   Best Strategy: ${memory.getMostEffectiveStrategy()}');
    // print('   Weaknesses Found: ${memory.exploitableWeaknesses.length}');
    // print('   Adapted Aggression: ${(adaptiveBehavior.adaptedAggression * 100).toInt()}%');
  }

  /// Get recommended strategy against this player
  String getRecommendedStrategy() {
    return memory.getMostEffectiveStrategy();
  }

  /// Check if AI should be extra cautious
  bool shouldBeExtraCautious() {
    return pattern.aggressivenessScore > 0.7 && pattern.killCount > 3;
  }

  /// Check if player has exploitable weakness
  bool hasExploitableWeakness(String weakness) {
    return memory.exploitableWeaknesses.contains(weakness);
  }

  /// Predict player's next likely position
  Vector2 predictPlayerPosition(Vector2 currentPos, Vector2 currentDir, double timeAhead) {
    // Use learned movement patterns to predict
    final speedMultiplier = (pattern.movementSpeedAvg / 150.0).clamp(0.5, 2.0);
    final prediction = currentPos + (currentDir * pattern.movementSpeedAvg * timeAhead * speedMultiplier);

    // Adjust for direction change tendency
    if (pattern.directionChangeFrequency > 0.2) {
      // Player changes direction often - less confident in prediction
      final uncertainty = pattern.directionChangeFrequency * 50;
      final random = Random();
      prediction.x += (random.nextDouble() - 0.5) * uncertainty;
      prediction.y += (random.nextDouble() - 0.5) * uncertainty;
    }

    return prediction;
  }

  /// Reset all learning (e.g., new game session)
  void reset() {
    pattern.reset();
    memory.strategySuccessRates.updateAll((key, value) => 0.5);
    memory.knownDangers.clear();
    memory.effectiveTactics.clear();
    memory.exploitableWeaknesses.clear();
    adaptiveBehavior.adaptedAggression = 0.5;
    adaptiveBehavior.adaptedCaution = 0.5;
    adaptiveBehavior.adaptedFoodFocus = 0.5;
    adaptiveBehavior.adaptedBoostUsage = 0.5;
    _totalInteractions = 0;
    _successfulPredictions = 0;
  }
}

// ============================================================================
// INTEGRATION HELPER
// ============================================================================

/// Extension methods to integrate learning into existing AI
extension LearningAIExtension on dynamic {
  /// Apply learned behavior modifications to base personality
  Map<String, double> applyLearning(
      Map<String, double> basePersonality,
      AdaptiveBehavior adaptive,
      ) {
    return {
      'aggression': (basePersonality['aggression']! * 0.4 +
          adaptive.getAdaptedTrait('aggression') * 0.6).clamp(0.0, 1.0),
      'caution': (basePersonality['caution']! * 0.4 +
          adaptive.getAdaptedTrait('caution') * 0.6).clamp(0.0, 1.0),
      'greed': (basePersonality['greed']! * 0.4 +
          adaptive.getAdaptedTrait('greed') * 0.6).clamp(0.0, 1.0),
      'riskTolerance': basePersonality['riskTolerance']!,
      'reactionSpeed': basePersonality['reactionSpeed']!,
      'boostPreference': (basePersonality['boostPreference']! * 0.4 +
          adaptive.getAdaptedTrait('boostPreference') * 0.6).clamp(0.0, 1.0),
    };
  }
}