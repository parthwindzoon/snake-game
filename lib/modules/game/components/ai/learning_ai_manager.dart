// lib/modules/game/components/ai/learning_ai_manager.dart
// INTEGRATION: Combines the improved AI with learning system

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/extensions.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../../data/service/settings_service.dart';
import '../../views/game_screen.dart';
import '../food/food_manager.dart';
import '../player/player_component.dart';
import 'ai_snake_data.dart';
import 'learning_ai_system.dart'; // Import the learning system

// Enhanced AI Personality with learning integration
class LearnedAiPersonality {
  // Base personality (fixed traits)
  final double baseAggression;
  final double baseCaution;
  final double baseGreed;
  final double riskTolerance;
  final double reactionSpeed;
  final double baseBoostPreference;

  // Current adapted values (change during gameplay)
  double currentAggression;
  double currentCaution;
  double currentGreed;
  double currentBoostPreference;

  LearnedAiPersonality({
    required this.baseAggression,
    required this.baseCaution,
    required this.baseGreed,
    required this.riskTolerance,
    required this.reactionSpeed,
    required this.baseBoostPreference,
  })  : currentAggression = baseAggression,
        currentCaution = baseCaution,
        currentGreed = baseGreed,
        currentBoostPreference = baseBoostPreference;

  factory LearnedAiPersonality.random(Random random) {
    return LearnedAiPersonality(
      baseAggression: _weightedRandom(random, 0.3, 0.7),
      baseCaution: _weightedRandom(random, 0.4, 0.8),
      baseGreed: _weightedRandom(random, 0.5, 0.9),
      riskTolerance: _weightedRandom(random, 0.3, 0.7),
      reactionSpeed: _weightedRandom(random, 0.6, 0.95),
      baseBoostPreference: _weightedRandom(random, 0.4, 0.8),
    );
  }

  static double _weightedRandom(Random r, double min, double max) {
    final u1 = r.nextDouble();
    final u2 = r.nextDouble();
    final randStdNormal = sqrt(-2.0 * log(u1)) * cos(2.0 * pi * u2);
    final value = 0.5 + (randStdNormal * 0.15);
    return (value.clamp(0.0, 1.0) * (max - min) + min).clamp(min, max);
  }

  /// Update personality based on learning
  void applyLearning(AdaptiveBehavior adaptive) {
    // Blend base personality with learned behavior (60% learned, 40% base)
    currentAggression = (baseAggression * 0.4 + adaptive.adaptedAggression * 0.6).clamp(0.0, 1.0);
    currentCaution = (baseCaution * 0.4 + adaptive.adaptedCaution * 0.6).clamp(0.0, 1.0);
    currentGreed = (baseGreed * 0.4 + adaptive.adaptedFoodFocus * 0.6).clamp(0.0, 1.0);
    currentBoostPreference = (baseBoostPreference * 0.4 + adaptive.adaptedBoostUsage * 0.6).clamp(0.0, 1.0);
  }

  // Getters for current values (use these instead of base values)
  double get aggression => currentAggression;
  double get caution => currentCaution;
  double get greed => currentGreed;
  double get boostPreference => currentBoostPreference;
}

// ============================================================================
// LEARNING AI MANAGER - Main class with full learning integration
// ============================================================================

class LearningAiManager extends Component with HasGameReference<SlitherGame> {
  final Random _random = Random();
  final FoodManager foodManager;
  final PlayerComponent player;
  final SettingsService _settingsService = Get.find<SettingsService>();

  final int numberOfSnakes;
  final List<AiSnakeData> snakes = [];
  final List<AiSnakeData> _dyingSnakes = [];

  // Learning system
  late final PlayerBehaviorAnalyzer behaviorAnalyzer;

  // Map snakes to their learned personalities
  final Map<AiSnakeData, LearnedAiPersonality> _personalities = {};

  // Decision tracking
  final Map<AiSnakeData, List<Vector2>> _recentTargets = {};
  final Map<AiSnakeData, double> _decisionTimers = {};
  final Map<AiSnakeData, Vector2?> _currentTarget = {};
  final Map<AiSnakeData, String> _currentStrategy = {};

  int _nextId = 0;
  int _frameCount = 0;
  int _cleanupCounter = 0;
  static const int CLEANUP_INTERVAL = 120;
  static const double MAX_DISTANCE_FROM_PLAYER = 1500.0;

  final Map<AiSnakeData, double> _collisionCooldowns = {};
  static const double COLLISION_COOLDOWN_TIME = 1.0;
  static const int AI_INITIAL_SEGMENT_COUNT = 10;

  final List<Vector2> _recentSpawnPositions = [];
  static const double MIN_SPAWN_SEPARATION = 400.0;

  LearningAiManager({
    required this.foodManager,
    required this.player,
    this.numberOfSnakes = 15,
  }) {
    behaviorAnalyzer = PlayerBehaviorAnalyzer();
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _spawnAllSnakes();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _frameCount++;

    // UPDATE LEARNING SYSTEM - Analyze player behavior
    _updateLearningSystem(dt);

    // Update collision cooldowns
    final cooldownsToRemove = <AiSnakeData>[];
    _collisionCooldowns.forEach((snake, cooldown) {
      final newCooldown = cooldown - dt;
      if (newCooldown <= 0) {
        cooldownsToRemove.add(snake);
      } else {
        _collisionCooldowns[snake] = newCooldown;
      }
    });
    for (final snake in cooldownsToRemove) {
      _collisionCooldowns.remove(snake);
    }

    final visibleRect = game.cameraComponent.visibleWorldRect.inflate(400);
    int activeCount = 0;
    int passiveCount = 0;

    // Update all alive snakes with learning-enhanced AI
    for (final snake in snakes) {
      if (snake.isDead) continue;

      _updateSnakeMovement(snake, dt);

      final isNearPlayer = _isNearPlayer(snake, 600);
      final onScreen = visibleRect.overlaps(snake.boundingBox);

      if (onScreen || isNearPlayer) {
        _updateActiveSnakeWithLearning(snake, dt);
        activeCount++;
      } else {
        _lightPassiveUpdate(snake, dt);
        passiveCount++;
      }
    }

    _updateDyingSnakes(dt);

    if (_frameCount % 3 == 0) {
      _checkAiVsAiCollisionsSafer(visibleRect);
    }

    final newlyDead = snakes.where((s) => s.isDead && !_dyingSnakes.contains(s)).toList();
    for (final snake in newlyDead) {
      _startDeathAnimation(snake);
    }

    _cleanupCounter++;
    if (_cleanupCounter >= CLEANUP_INTERVAL) {
      _cleanupCounter = 0;
      _performPeriodicCleanup();
    }

    _ensureMinSnakesAroundPlayer();

    if (_frameCount % 180 == 0) {
      debugPrint(
        "🧠 Learning AI - Active: $activeCount | Passive: $passiveCount | Total: ${snakes.length}",
      );
    }
  }

  // ============================================================================
  // LEARNING SYSTEM UPDATE
  // ============================================================================

  void _updateLearningSystem(double dt) {
    // Gather player data
    final playerPos = player.position;
    final playerAngle = player.headAngle;
    final isBoosting = player.playerController.isBoosting.value;
    final foodCount = player.playerController.foodScore.value;
    final killCount = player.playerController.kills.value;

    // Get nearby AI snake positions
    final nearbyAiSnakes = snakes
        .where((s) => !s.isDead && s.position.distanceTo(playerPos) < 400)
        .map((s) => s.position)
        .toList();

    // Analyze player behavior
    behaviorAnalyzer.analyze(
      playerPos,
      playerAngle,
      isBoosting,
      foodCount,
      killCount,
      nearbyAiSnakes,
      dt,
    );

    // Update all AI personalities with learned behavior
    _personalities.forEach((snake, personality) {
      personality.applyLearning(behaviorAnalyzer.adaptiveBehavior);
    });
  }

  // ============================================================================
  // LEARNING-ENHANCED AI UPDATE
  // ============================================================================

  void _updateActiveSnakeWithLearning(AiSnakeData snake, double dt) {
    final personality = _personalities[snake]!;

    // Update decision timer
    _decisionTimers[snake] = (_decisionTimers[snake] ?? 0) - dt;

    // Make decisions at varied intervals based on reaction speed
    final decisionInterval = 0.3 + ((1.0 - personality.reactionSpeed) * 0.5);
    if (_decisionTimers[snake]! <= 0) {
      _makeLearningBasedDecision(snake, personality);
      _decisionTimers[snake] = decisionInterval + (_random.nextDouble() * 0.2 - 0.1);
    }

    // Handle boost with learning-enhanced logic
    _handleLearningBasedBoostLogic(snake, personality, dt);

    // Calculate movement with learning-enhanced targeting
    final desired = _calculateLearningBasedDirection(snake, personality);
    if (desired.length2 > 0) {
      snake.targetDirection = desired.normalized();
    }

    // Smooth turning
    final baseRotationSpeed = 2.0 + (personality.reactionSpeed * 1.5);
    final rotationSpeed = baseRotationSpeed * pi;
    final targetAngle = snake.targetDirection.screenAngle();
    final diff = _getAngleDiff(snake.angle, targetAngle);
    final delta = rotationSpeed * dt;

    final turnNoise = (_random.nextDouble() - 0.5) * 0.1 * (1.0 - personality.reactionSpeed);
    snake.angle += ((diff.abs() < delta) ? diff : delta * diff.sign) + turnNoise;

    // Move
    final baseSpeed = snake.isBoosting ? snake.boostSpeed : snake.baseSpeed;
    final speedVariation = 1.0 + (_random.nextDouble() - 0.5) * 0.1;
    final speed = baseSpeed * speedVariation;
    final forward = Vector2(cos(snake.angle), sin(snake.angle));
    snake.position.add(forward * speed * dt);

    // Update body
    final spacing = snake.segmentSpacing;
    Vector2 leader = snake.position;
    for (int i = 0; i < snake.bodySegments.length; i++) {
      final seg = snake.bodySegments[i];
      final d = seg.distanceTo(leader);
      if (d > spacing) {
        seg.add((leader - seg).normalized() * (d - spacing));
      }
      leader = seg;
    }

    _checkFoodConsumptionWithAnimation(snake);
    _enforceBounds(snake);
    _updateBoundingBox(snake);
  }

  // ============================================================================
  // LEARNING-BASED DECISION MAKING
  // ============================================================================

  void _makeLearningBasedDecision(AiSnakeData snake, LearnedAiPersonality personality) {
    final pos = snake.position;
    final bounds = SlitherGame.playArea;

    // Priority 1: Boundary avoidance
    if (!_isInsideBounds(pos, bounds.deflate(200))) {
      snake.aiState = AiState.avoiding_boundary;
      _currentTarget[snake] = null;
      _currentStrategy[snake] = 'boundary_avoid';
      return;
    }

    // Get situational awareness
    final nearbyThreats = _getNearbyThreats(snake);
    final nearbyFood = _getNearbyFood(snake.position, 350);
    final playerDist = pos.distanceTo(player.position);
    final playerRadiusDiff = snake.headRadius - player.playerController.headRadius.value;

    // USE LEARNING: Get recommended strategy based on what's working
    final recommendedStrategy = behaviorAnalyzer.getRecommendedStrategy();

    // Score different actions (influenced by learning)
    Map<AiState, double> actionScores = {};

    // Check if player has exploitable weaknesses
    final playerIsPassive = behaviorAnalyzer.hasExploitableWeakness('passive_playstyle');
    final playerRetreatsOften = behaviorAnalyzer.hasExploitableWeakness('frequent_retreater');
    final playerBoostDependent = behaviorAnalyzer.hasExploitableWeakness('boost_dependent');

    // Exploit learned weaknesses
    if (playerIsPassive && playerRadiusDiff > 0) {
      // Player is passive and we're bigger - be aggressive!
      actionScores[AiState.attacking] = 0.9;
      print('🎯 Exploiting passive player!');
    }

    if (playerRetreatsOften && playerDist < 300) {
      // Player retreats often - pursue aggressively
      actionScores[AiState.chasing] = 0.85;
      print('🎯 Exploiting retreating player!');
    }

    if (playerBoostDependent && !player.playerController.isBoosting.value) {
      // Player relies on boost but isn't boosting - opportunity!
      actionScores[AiState.attacking] = 0.8;
      print('🎯 Player vulnerable without boost!');
    }

    // Score food seeking (adjusted by learned food priority)
    if (nearbyFood.isNotEmpty) {
      final baseScore = personality.greed * 0.8;
      final learningBonus = behaviorAnalyzer.pattern.foodPriorityScore > 0.7 ? 0.2 : 0.0;
      actionScores[AiState.seeking_food] = baseScore + learningBonus;
    }

    // Score player interaction (heavily influenced by learning)
    if (playerDist < 400) {
      // Check if AI should be extra cautious based on player's skill
      final extraCautious = behaviorAnalyzer.shouldBeExtraCautious();

      if (playerRadiusDiff > 3) {
        // We're bigger
        final baseAttackScore = personality.aggression * 0.7;
        final cautionPenalty = extraCautious ? -0.3 : 0.0;
        actionScores[AiState.attacking] = baseAttackScore + cautionPenalty;
      } else if (playerRadiusDiff < -3) {
        // Player is bigger
        final baseFleeScore = personality.caution * 0.8;
        final panicBonus = extraCautious ? 0.2 : 0.0;
        actionScores[AiState.fleeing] = baseFleeScore + panicBonus;
      }
    }

    // Apply successful strategy bias
    final strategyBonus = behaviorAnalyzer.memory.strategySuccessRates[recommendedStrategy] ?? 0.5;
    if (recommendedStrategy == 'aggressive_chase' && actionScores.containsKey(AiState.attacking)) {
      actionScores[AiState.attacking] = actionScores[AiState.attacking]! + (strategyBonus * 0.2);
    } else if (recommendedStrategy == 'defensive_flee' && actionScores.containsKey(AiState.fleeing)) {
      actionScores[AiState.fleeing] = actionScores[AiState.fleeing]! + (strategyBonus * 0.2);
    } else if (recommendedStrategy == 'food_competition' && actionScores.containsKey(AiState.seeking_food)) {
      actionScores[AiState.seeking_food] = actionScores[AiState.seeking_food]! + (strategyBonus * 0.2);
    }

    // Default actions
    final distFromCenter = pos.distanceTo(Vector2.zero());
    if (distFromCenter > 800) {
      actionScores[AiState.seeking_center] = 0.5;
    } else {
      actionScores[AiState.wandering] = 0.3 * (1.0 - personality.greed);
    }

    // Add randomness
    actionScores.forEach((state, score) {
      actionScores[state] = score + (_random.nextDouble() * personality.riskTolerance * 0.2);
    });

    // Choose best action
    if (actionScores.isEmpty) {
      snake.aiState = AiState.wandering;
      _currentStrategy[snake] = 'wandering';
    } else {
      final chosen = actionScores.entries.reduce((a, b) => a.value > b.value ? a : b);
      snake.aiState = chosen.key;
      _currentStrategy[snake] = chosen.key.toString();
    }

    // Set target
    _setLearningBasedTarget(snake, personality);
  }

  // ============================================================================
  // LEARNING-BASED TARGETING
  // ============================================================================

  void _setLearningBasedTarget(AiSnakeData snake, LearnedAiPersonality personality) {
    switch (snake.aiState) {
      case AiState.seeking_food:
        final food = _getNearbyFood(snake.position, 350);
        if (food.isNotEmpty) {
          _currentTarget[snake] = food.first.position;
        }
        break;
      case AiState.attacking:
      case AiState.chasing:
      // USE LEARNING: Predict player position based on learned patterns
        final playerDir = player.playerController.currentDir;
        final predictionTime = 0.5 + (1.0 - personality.reactionSpeed) * 0.5;

        _currentTarget[snake] = behaviorAnalyzer.predictPlayerPosition(
          player.position,
          playerDir,
          predictionTime,
        );

        print('🎯 Predicting player movement for interception');
        break;
      case AiState.fleeing:
        _currentTarget[snake] = null;
        break;
      default:
        _currentTarget[snake] = null;
    }
  }

  Vector2 _calculateLearningBasedDirection(AiSnakeData snake, LearnedAiPersonality personality) {
    final currentDir = Vector2(cos(snake.angle), sin(snake.angle));
    Vector2 desired = Vector2.zero();

    switch (snake.aiState) {
      case AiState.avoiding_boundary:
        desired = _getBoundaryAvoidDir(snake);
        break;
      case AiState.seeking_center:
        final toCenter = (Vector2.zero() - snake.position).normalized();
        final toPlayer = (player.position - snake.position).normalized();
        desired = (toCenter * 0.6 + toPlayer * 0.4).normalized();
        break;
      case AiState.seeking_food:
        if (_currentTarget[snake] != null) {
          desired = (_currentTarget[snake]! - snake.position).normalized();
        } else {
          desired = currentDir;
        }
        break;
      case AiState.chasing:
      case AiState.attacking:
        if (_currentTarget[snake] != null) {
          desired = (_currentTarget[snake]! - snake.position).normalized();
        } else {
          desired = (player.position - snake.position).normalized();
        }
        break;
      case AiState.fleeing:
        desired = _getRealisticFleeDir(snake, personality);
        break;
      case AiState.defending:
        desired = _getDefendDir(snake);
        break;
      case AiState.wandering:
      default:
        desired = _getRealisticWanderDir(snake, personality);
    }

    final blendFactor = 0.3 + (personality.reactionSpeed * 0.4);
    return (currentDir * (1.0 - blendFactor) + desired * blendFactor).normalized();
  }

  void _handleLearningBasedBoostLogic(AiSnakeData snake, LearnedAiPersonality personality, double dt) {
    if (snake.boostCooldownTimer > 0) {
      snake.boostCooldownTimer -= dt;
    }

    if (snake.isBoosting) {
      snake.boostDuration -= dt;
      if (snake.boostDuration <= 0 || snake.segmentCount <= AI_INITIAL_SEGMENT_COUNT + 2) {
        snake.isBoosting = false;
        snake.boostCooldownTimer = 1.5 + (_random.nextDouble() * 1.0);

        // Record strategy success/failure
        if (_currentStrategy[snake] == 'attacking') {
          final distToPlayer = snake.position.distanceTo(player.position);
          behaviorAnalyzer.memory.recordStrategySuccess(
            'boost_intercept',
            distToPlayer < 150,
          );
        }
      }
    }

    if (!snake.isBoosting &&
        snake.boostCooldownTimer <= 0 &&
        snake.segmentCount > AI_INITIAL_SEGMENT_COUNT + 5) {

      // Learning-influenced boost decision
      final playerBoosting = player.playerController.isBoosting.value;
      final shouldBoost = _shouldBoostWithLearning(snake, personality, playerBoosting);

      if (shouldBoost) {
        snake.isBoosting = true;
        final baseDuration = 0.4 + (personality.boostPreference * 0.6);
        snake.boostDuration = baseDuration + (_random.nextDouble() * 0.3);
      }
    }
  }

  bool _shouldBoostWithLearning(AiSnakeData snake, LearnedAiPersonality personality, bool playerBoosting) {
    final boostThreshold = 1.0 - personality.boostPreference;

    // If player is boost-dependent and currently boosting, match them
    if (behaviorAnalyzer.hasExploitableWeakness('boost_dependent') && playerBoosting) {
      return _random.nextDouble() > 0.3; // 70% chance to match
    }

    // If player rarely boosts, use boost for advantage
    if (behaviorAnalyzer.pattern.boostUsageScore < 0.3) {
      return _random.nextDouble() > (boostThreshold * 0.6);
    }

    // Normal boost logic
    switch (snake.aiState) {
      case AiState.fleeing:
        return _random.nextDouble() > (boostThreshold * 0.3);
      case AiState.attacking:
        return _random.nextDouble() > (boostThreshold * 0.4);
      case AiState.chasing:
        return _random.nextDouble() > (boostThreshold * 0.6);
      default:
        return _random.nextDouble() > (boostThreshold * 0.9);
    }
  }

  // ============================================================================
  // HELPER METHODS (Keep all existing methods from previous code)
  // ============================================================================

  List<dynamic> _getNearbyFood(Vector2 position, double maxDist) {
    final nearby = <dynamic>[];
    final maxDistSq = maxDist * maxDist;
    for (final food in foodManager.eatableFoodList) {
      if (position.distanceToSquared(food.position) < maxDistSq) {
        nearby.add(food);
      }
    }
    nearby.sort((a, b) => position.distanceToSquared(a.position)
        .compareTo(position.distanceToSquared(b.position)));
    return nearby;
  }

  Vector2 _getRealisticWanderDir(AiSnakeData snake, LearnedAiPersonality personality) {
    if (_random.nextDouble() < 0.03) {
      final current = Vector2(cos(snake.angle), sin(snake.angle));
      final turnAmount = (_random.nextDouble() - 0.5) * pi * (0.5 + personality.riskTolerance * 0.5);
      return Vector2(
        current.x * cos(turnAmount) - current.y * sin(turnAmount),
        current.x * sin(turnAmount) + current.y * cos(turnAmount),
      ).normalized();
    }

    final toCenter = (Vector2.zero() - snake.position).normalized() * (0.2 * personality.caution);
    final toPlayer = (player.position - snake.position).normalized() * (0.2 * personality.aggression);
    final current = Vector2(cos(snake.angle), sin(snake.angle)) * 0.6;
    return (current + toCenter + toPlayer).normalized();
  }

  Vector2 _getRealisticFleeDir(AiSnakeData snake, LearnedAiPersonality personality) {
    Vector2 flee = Vector2.zero();
    int threatCount = 0;

    final playerDist = snake.position.distanceTo(player.position);
    if (playerDist < 400) {
      final fleeWeight = (400 - playerDist) / 400;
      flee += (snake.position - player.position).normalized() * fleeWeight;
      threatCount++;
    }

    for (final other in snakes) {
      if (other == snake || other.isDead) continue;
      if (other.headRadius > snake.headRadius + 2) {
        final dist = snake.position.distanceTo(other.position);
        if (dist < 300) {
          final fleeWeight = (300 - dist) / 300;
          flee += (snake.position - other.position).normalized() * fleeWeight * personality.caution;
          threatCount++;
        }
      }
    }

    if (threatCount == 0) {
      return Vector2(cos(snake.angle), sin(snake.angle));
    }

    final panicLevel = (threatCount / 3.0).clamp(0.0, 1.0) * (1.0 - personality.caution);
    final randomAngle = (_random.nextDouble() - 0.5) * pi * 0.3 * panicLevel;
    final fleeNormalized = flee.normalized();

    return Vector2(
      fleeNormalized.x * cos(randomAngle) - fleeNormalized.y * sin(randomAngle),
      fleeNormalized.x * sin(randomAngle) + fleeNormalized.y * cos(randomAngle),
    ).normalized();
  }

  // [Include ALL other helper methods from the previous code]
  // _spawnAllSnakes, _spawnSnakeAtPosition, _updateSnakeMovement, etc.
  // (Same implementations as before)

  void _spawnAllSnakes() {
    print('🧠 Spawning $numberOfSnakes AI snakes with learning capabilities...');
    for (int i = 0; i < numberOfSnakes; i++) {
      final spawnPos = _findSeparatedSpawnPosition();
      if (spawnPos != null) {
        _spawnSnakeAtPosition(spawnPos, isInitialSpawn: true);
      }
    }
  }

  void _spawnSnakeAtPosition(Vector2 pos, {bool isInitialSpawn = false}) async {
    int initCount = AI_INITIAL_SEGMENT_COUNT;
    if (!isInitialSpawn) {
      final playerSegments = player.bodySegments.length;
      final minSegments = max(AI_INITIAL_SEGMENT_COUNT, (playerSegments * 0.6).round());
      final maxSegments = (playerSegments * 1.2).round().clamp(AI_INITIAL_SEGMENT_COUNT, 50);
      initCount = minSegments + _random.nextInt(max(1, maxSegments - minSegments + 1));
    }

    final randomSkin = _getRandomPlayerSkin();
    final randomHead = _settingsService.allHeads[_random.nextInt(_settingsService.allHeads.length)];
    final headSprite = await game.loadSprite(randomHead);
    final playerPosition = player.position;
    final towardPlayerDirection = (playerPosition - pos).normalized();

    final snake = AiSnakeData(
      position: pos.clone(),
      skinColors: randomSkin,
      targetDirection: towardPlayerDirection,
      segmentCount: initCount,
      segmentSpacing: 13.0 * 0.6,
      baseSpeed: 70,
      boostSpeed: 140,
      minRadius: 16.0,
      maxRadius: 50.0,
      headSprite: headSprite,
    );

    // Assign learned personality
    _personalities[snake] = LearnedAiPersonality.random(_random);
    _decisionTimers[snake] = _random.nextDouble() * 0.5;
    _recentTargets[snake] = [];
    _currentStrategy[snake] = 'spawning';

    final bonus = (initCount / 25).floor().toDouble();
    snake.headRadius = (16.0 + bonus).clamp(snake.minRadius, snake.maxRadius);
    snake.bodyRadius = snake.headRadius - 1.0;
    snake.foodScore = (initCount - AI_INITIAL_SEGMENT_COUNT) * snake.foodPerSegment;

    snake.bodySegments.clear();
    snake.path.clear();
    final awayFromPlayerDirection = -towardPlayerDirection;
    for (int i = 0; i < initCount; i++) {
      final segmentPos = pos + (awayFromPlayerDirection * snake.segmentSpacing * (i + 1));
      snake.bodySegments.add(segmentPos);
      snake.path.add(segmentPos.clone());
    }

    snake.aiState = AiState.seeking_center;
    snakes.add(snake);
    _updateBoundingBox(snake);
  }

  // [Include ALL other methods from previous implementations]

  List<Color> _getRandomPlayerSkin() {
    final allSkins = _settingsService.allSkins;
    if (allSkins.isEmpty) return _getBasicRandomSkin();
    final randomSkinIndex = _random.nextInt(allSkins.length);
    return List<Color>.from(allSkins[randomSkinIndex]);
  }

  List<Color> _getBasicRandomSkin() {
    final baseHue = _random.nextDouble() * 360;
    return List.generate(6, (i) {
      final h = (baseHue + i * 15) % 360;
      return HSVColor.fromAHSV(1, h, 0.8, 0.9).toColor();
    });
  }

  Vector2? _findSeparatedSpawnPosition() {
    final candidates = _generateOffscreenSpawnPositions();
    for (final candidate in candidates) {
      bool tooClose = false;
      for (final recent in _recentSpawnPositions) {
        if (candidate.distanceTo(recent) < MIN_SPAWN_SEPARATION) {
          tooClose = true;
          break;
        }
      }
      if (!tooClose) {
        _recentSpawnPositions.add(candidate);
        return candidate;
      }
    }
    if (candidates.isNotEmpty) {
      final fallback = candidates.first;
      _recentSpawnPositions.add(fallback);
      return fallback;
    }
    return null;
  }

  List<Vector2> _generateOffscreenSpawnPositions() {
    final visibleRect = game.cameraComponent.visibleWorldRect;
    final positions = <Vector2>[];
    final maxSnakeLength = AI_INITIAL_SEGMENT_COUNT * 13.0 + 200;
    final spawnDistance = max(visibleRect.width, visibleRect.height) / 2 + maxSnakeLength;
    final centerX = visibleRect.center.dx;
    final centerY = visibleRect.center.dy;

    final angles = [0, pi / 4, pi / 2, 3 * pi / 4, pi, 5 * pi / 4, 3 * pi / 2, 7 * pi / 4];
    for (final angle in angles) {
      final x = centerX + cos(angle) * spawnDistance;
      final y = centerY + sin(angle) * spawnDistance;
      final clampedX = x.clamp(SlitherGame.worldBounds.left + 100, SlitherGame.worldBounds.right - 100);
      final clampedY = y.clamp(SlitherGame.worldBounds.top + 100, SlitherGame.worldBounds.bottom - 100);
      positions.add(Vector2(clampedX, clampedY));
    }
    positions.shuffle(_random);
    return positions;
  }

  void _updateSnakeMovement(AiSnakeData snake, double dt) {
    final moveSpeed = snake.isBoosting ? snake.boostSpeed : snake.baseSpeed;
    final moveDir = Vector2(cos(snake.angle), sin(snake.angle));
    snake.position += moveDir * moveSpeed * dt;

    snake.bodySegments.insert(0, snake.position.clone());
    while (snake.bodySegments.length > snake.segmentCount) {
      snake.bodySegments.removeLast();
    }
    snake.rebuildBoundingBox();
  }

  void killSnakeAsRevenge(AiSnakeData snake) {
    if (snake.isDead) return;
    print('REVENGE KILL: Eliminating AI snake that killed the player!');
    snake.isDead = true;
    _startDeathAnimation(snake, isRevengeDeath: true);

    // Record this as a successful strategy for the player
    behaviorAnalyzer.memory.recordStrategySuccess('player_revenge', true);
  }

  void _startDeathAnimation(AiSnakeData snake, {bool isRevengeDeath = false}) {
    // print('Starting death animation for snake with ${snake.segmentCount} segments');
    _dyingSnakes.add(snake);
    snake.deathAnimationTimer = isRevengeDeath
        ? AiSnakeData.deathAnimationDuration * 1.5
        : AiSnakeData.deathAnimationDuration;
    snake.originalScale = 1.0;
    foodManager.scatterFoodFromAiSnakeBody(
        snake.position, snake.headRadius, snake.bodySegments, isRevengeDeath);
  }

  void _updateDyingSnakes(double dt) {
    final List<AiSnakeData> toRemove = [];
    for (final snake in _dyingSnakes) {
      snake.deathAnimationTimer -= dt;
      final progress = 1.0 - (snake.deathAnimationTimer / AiSnakeData.deathAnimationDuration);
      snake.scale = (1.0 - progress).clamp(0.0, 1.0);
      snake.opacity = snake.scale;
      if (snake.deathAnimationTimer <= 0) {
        toRemove.add(snake);
      }
    }
    for (final snake in toRemove) {
      _dyingSnakes.remove(snake);
      snakes.remove(snake);
      _collisionCooldowns.remove(snake);
      _personalities.remove(snake);
      _recentTargets.remove(snake);
      _decisionTimers.remove(snake);
      _currentTarget.remove(snake);
      _currentStrategy.remove(snake);
    }
  }

  void _checkAiVsAiCollisionsSafer(Rect visibleRect) {
    final visibleSnakes = snakes.where((s) =>
    !s.isDead && visibleRect.overlaps(s.boundingBox)).toList();

    for (int i = 0; i < visibleSnakes.length; i++) {
      final snake1 = visibleSnakes[i];
      if (snake1.isDead || _collisionCooldowns.containsKey(snake1)) continue;

      for (int j = i + 1; j < visibleSnakes.length; j++) {
        final snake2 = visibleSnakes[j];
        if (snake2.isDead || _collisionCooldowns.containsKey(snake2)) continue;
        _checkCollisionBetweenAiSnakes(snake1, snake2);
      }
    }
  }

  void _checkCollisionBetweenAiSnakes(AiSnakeData snake1, AiSnakeData snake2) {
    final headDistance = snake1.position.distanceTo(snake2.position);
    final requiredHeadDistance = (snake1.headRadius + snake2.headRadius) * 0.9;

    if (headDistance <= requiredHeadDistance) {
      if (snake1.headRadius > snake2.headRadius + 2.0) {
        snake2.isDead = true;
        _growSnakeWithFood(snake1, snake2.segmentCount ~/ 8);
        _collisionCooldowns[snake1] = COLLISION_COOLDOWN_TIME;
      } else if (snake2.headRadius > snake1.headRadius + 2.0) {
        snake1.isDead = true;
        _growSnakeWithFood(snake2, snake1.segmentCount ~/ 8);
        _collisionCooldowns[snake2] = COLLISION_COOLDOWN_TIME;
      } else {
        snake1.isDead = true;
        snake2.isDead = true;
      }
      return;
    }

    for (int i = 3; i < snake2.bodySegments.length; i += 2) {
      final segment = snake2.bodySegments[i];
      final distance = snake1.position.distanceTo(segment);
      final requiredDistance = (snake1.headRadius + snake2.bodyRadius) * 0.85;
      if (distance <= requiredDistance) {
        snake2.isDead = true;
        _growSnakeWithFood(snake1, snake2.segmentCount ~/ 8);
        _collisionCooldowns[snake1] = COLLISION_COOLDOWN_TIME;
        return;
      }
    }

    for (int i = 3; i < snake1.bodySegments.length; i += 2) {
      final segment = snake1.bodySegments[i];
      final distance = snake2.position.distanceTo(segment);
      final requiredDistance = (snake2.headRadius + snake1.bodyRadius) * 0.85;
      if (distance <= requiredDistance) {
        snake1.isDead = true;
        _growSnakeWithFood(snake2, snake1.segmentCount ~/ 8);
        _collisionCooldowns[snake2] = COLLISION_COOLDOWN_TIME;
        return;
      }
    }
  }

  void _performPeriodicCleanup() {
    final playerPos = player.position;
    int removedCount = 0;

    snakes.removeWhere((snake) {
      if (snake.isDead) return false;
      final distance = snake.position.distanceTo(playerPos);
      if (distance > MAX_DISTANCE_FROM_PLAYER) {
        removedCount++;
        _collisionCooldowns.remove(snake);
        _personalities.remove(snake);
        _recentTargets.remove(snake);
        _decisionTimers.remove(snake);
        _currentTarget.remove(snake);
        _currentStrategy.remove(snake);
        return true;
      }
      return false;
    });

    if (removedCount > 0) {
      debugPrint("Cleaned up $removedCount distant AI snakes");
    }

    if (snakes.length > 25) {
      final excess = snakes.length - 20;
      final toRemove = snakes
          .where((s) => !s.isDead)
          .where((s) => s.position.distanceTo(playerPos) > 1000)
          .take(excess)
          .toList();
      for (final snake in toRemove) {
        snakes.remove(snake);
        _collisionCooldowns.remove(snake);
        _personalities.remove(snake);
        _recentTargets.remove(snake);
        _decisionTimers.remove(snake);
        _currentTarget.remove(snake);
        _currentStrategy.remove(snake);
      }
    }

    if (_recentSpawnPositions.length > 10) {
      _recentSpawnPositions.removeRange(0, _recentSpawnPositions.length - 10);
    }
  }

  void _ensureMinSnakesAroundPlayer() {
    const minActive = 10;
    const maxActive = 15;
    const spawnRadius = 1000.0;

    final near = snakes.where((s) =>
    !s.isDead && s.position.distanceTo(player.position) < spawnRadius).length;

    if (near >= minActive && near <= maxActive) return;

    if (near < minActive) {
      final need = (minActive - near).clamp(0, 2);
      for (int i = 0; i < need; i++) {
        Vector2? spawnPos = _findSeparatedSpawnPosition();
        if (spawnPos != null) {
          _spawnSnakeAtPosition(spawnPos, isInitialSpawn: false);
        }
      }
    }
  }

  void _checkFoodConsumptionWithAnimation(AiSnakeData snake) {
    final eR = snake.headRadius + 15;
    final eatRadiusSquared = eR * eR;

    final candidates = foodManager.eatableFoodList.where((food) {
      final ds = snake.position.distanceToSquared(food.position);
      return ds <= eatRadiusSquared;
    }).toList();

    for (final food in candidates) {
      foodManager.startConsumingFood(food, snake.position);
      _growSnakeWithFood(snake, food.growth);
      foodManager.spawnFood(snake.position);
    }
  }

  void _growSnakeWithFood(AiSnakeData snake, int foodValue) {
    snake.growFromFood(foodValue);
  }

  void _updateBoundingBox(AiSnakeData snake) => snake.rebuildBoundingBox();

  void _enforceBounds(AiSnakeData snake) {
    final b = SlitherGame.playArea;
    if (snake.position.x < b.left) snake.position.x = b.left;
    if (snake.position.x > b.right) snake.position.x = b.right;
    if (snake.position.y < b.top) snake.position.y = b.top;
    if (snake.position.y > b.bottom) snake.position.y = b.bottom;
  }

  double _getAngleDiff(double a, double b) {
    var diff = (b - a + pi) % (2 * pi) - pi;
    return diff < -pi ? diff + 2 * pi : diff;
  }

  bool _isInsideBounds(Vector2 p, Rect r) =>
      p.x >= r.left && p.x <= r.right && p.y >= r.top && p.y <= r.bottom;

  List<AiSnakeData> _getNearbyThreats(AiSnakeData snake) {
    final out = <AiSnakeData>[];
    for (final o in snakes) {
      if (o == snake || o.isDead) continue;
      final d = snake.position.distanceTo(o.position);
      if (d < 300) out.add(o);
    }
    return out;
  }

  Vector2 _getBoundaryAvoidDir(AiSnakeData snake) {
    final p = snake.position;
    final b = SlitherGame.playArea;
    Vector2 force = Vector2.zero();
    const safe = 400.0;

    if (p.x - b.left < safe) force.x += ((safe - (p.x - b.left)) / safe) * 2;
    if (b.right - p.x < safe) force.x -= ((safe - (b.right - p.x)) / safe) * 2;
    if (p.y - b.top < safe) force.y += ((safe - (p.y - b.top)) / safe) * 2;
    if (b.bottom - p.y < safe) force.y -= ((safe - (b.bottom - p.y)) / safe) * 2;

    if (force.length < 0.1) force = (Vector2.zero() - p).normalized();
    return force.normalized();
  }

  Vector2 _getDefendDir(AiSnakeData snake) {
    final toPlayer = (player.position - snake.position).normalized();
    final perp = Vector2(-toPlayer.y, toPlayer.x);
    final side = (_random.nextDouble() < 0.5 ? 1.0 : -1.0);
    return (perp * side * 0.7 + (-toPlayer) * 0.3).normalized();
  }

  bool _isNearPlayer(AiSnakeData snake, double range) =>
      snake.position.distanceTo(player.position) < range;

  void _lightPassiveUpdate(AiSnakeData snake, double dt) {
    const speed = 50.0;
    final toCenter = (Vector2.zero() - snake.position).normalized() * 0.3;
    final toPlayer = (player.position - snake.position).normalized() * 0.7;
    final combinedDirection = (toCenter + toPlayer).normalized();
    final currentDir = Vector2(cos(snake.angle), sin(snake.angle));
    final newDirection = (currentDir * 0.8 + combinedDirection * 0.2).normalized();

    snake.angle = newDirection.screenAngle();
    snake.position.add(newDirection * speed * dt);

    final spacing = snake.segmentSpacing;
    Vector2 leader = snake.position;
    for (int i = 0; i < snake.bodySegments.length && i < 5; i++) {
      final seg = snake.bodySegments[i];
      final d = seg.distanceTo(leader);
      if (d > spacing) {
        seg.add((leader - seg).normalized() * (d - spacing));
      }
      leader = seg;
    }

    _enforceBounds(snake);
    _updateBoundingBox(snake);
  }

  Future<AiSnakeData> spawnNewSnake({Vector2? pos}) async {
    Vector2 startPos = pos ?? _findSeparatedSpawnPosition() ?? Vector2.zero();
    final playerPos = player.position;
    final dir = (playerPos - startPos).normalized();
    final randomHead = _settingsService.allHeads[_random.nextInt(_settingsService.allHeads.length)];
    final headSprite = await game.loadSprite(randomHead);

    final playerSegments = player.bodySegments.length;
    final minSegments = max(AI_INITIAL_SEGMENT_COUNT, (playerSegments * 0.6).round());
    final maxSegments = (playerSegments * 1.2).round().clamp(AI_INITIAL_SEGMENT_COUNT, 50);
    final segmentCount = minSegments + _random.nextInt(max(1, maxSegments - minSegments + 1));

    final snake = AiSnakeData(
      position: startPos,
      skinColors: _getRandomPlayerSkin(),
      targetDirection: dir,
      segmentCount: segmentCount,
      segmentSpacing: 10,
      baseSpeed: 70,
      boostSpeed: 140,
      minRadius: 16,
      maxRadius: 50,
      headSprite: headSprite,
    );

    _personalities[snake] = LearnedAiPersonality.random(_random);
    _decisionTimers[snake] = _random.nextDouble() * 0.5;
    _recentTargets[snake] = [];
    _currentStrategy[snake] = 'spawning';

    final bonus = (segmentCount / 25).floor().toDouble();
    snake.headRadius = (16.0 + bonus).clamp(snake.minRadius, snake.maxRadius);
    snake.bodyRadius = snake.headRadius - 1.0;
    snake.foodScore = (segmentCount - AI_INITIAL_SEGMENT_COUNT) * snake.foodPerSegment;

    for (int i = 0; i < snake.segmentCount; i++) {
      snake.bodySegments.add(startPos - dir * (i * snake.segmentSpacing));
    }
    snake.rebuildBoundingBox();

    snakes.add(snake);
    return snake;
  }

  /// Reset learning system for new game
  void resetLearning() {
    behaviorAnalyzer.reset();
  }

  int get totalSnakeCount => snakes.length;
  int get aliveSnakeCount => snakes.where((s) => !s.isDead).length;
}