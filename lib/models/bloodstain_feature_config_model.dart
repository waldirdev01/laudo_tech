class BloodstainFeatureMetadata {
  final String name;
  final String scope;
  final String role;
  final String domainProfile;

  const BloodstainFeatureMetadata({
    required this.name,
    required this.scope,
    required this.role,
    required this.domainProfile,
  });

  factory BloodstainFeatureMetadata.fromJson(Map<String, dynamic> json) {
    return BloodstainFeatureMetadata(
      name: json['name'] as String? ?? '',
      scope: json['scope'] as String? ?? '',
      role: json['role'] as String? ?? '',
      domainProfile: json['domain_profile'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'scope': scope,
    'role': role,
    'domain_profile': domainProfile,
  };

  BloodstainFeatureMetadata copyWith({
    String? name,
    String? scope,
    String? role,
    String? domainProfile,
  }) {
    return BloodstainFeatureMetadata(
      name: name ?? this.name,
      scope: scope ?? this.scope,
      role: role ?? this.role,
      domainProfile: domainProfile ?? this.domainProfile,
    );
  }
}

class BloodstainFeatureBehavior {
  final bool conservativeMode;
  final bool allowIndeterminateOutput;
  final bool requireHumanReviewFlags;
  final bool blockWithoutMinimumInputs;
  final bool confidenceCapRequired;

  const BloodstainFeatureBehavior({
    required this.conservativeMode,
    required this.allowIndeterminateOutput,
    required this.requireHumanReviewFlags,
    required this.blockWithoutMinimumInputs,
    required this.confidenceCapRequired,
  });

  factory BloodstainFeatureBehavior.fromJson(Map<String, dynamic> json) {
    return BloodstainFeatureBehavior(
      conservativeMode: json['conservative_mode'] as bool? ?? true,
      allowIndeterminateOutput:
          json['allow_indeterminate_output'] as bool? ?? true,
      requireHumanReviewFlags:
          json['require_human_review_flags'] as bool? ?? true,
      blockWithoutMinimumInputs:
          json['block_without_minimum_inputs'] as bool? ?? true,
      confidenceCapRequired: json['confidence_cap_required'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'conservative_mode': conservativeMode,
    'allow_indeterminate_output': allowIndeterminateOutput,
    'require_human_review_flags': requireHumanReviewFlags,
    'block_without_minimum_inputs': blockWithoutMinimumInputs,
    'confidence_cap_required': confidenceCapRequired,
  };

  BloodstainFeatureBehavior copyWith({
    bool? conservativeMode,
    bool? allowIndeterminateOutput,
    bool? requireHumanReviewFlags,
    bool? blockWithoutMinimumInputs,
    bool? confidenceCapRequired,
  }) {
    return BloodstainFeatureBehavior(
      conservativeMode: conservativeMode ?? this.conservativeMode,
      allowIndeterminateOutput:
          allowIndeterminateOutput ?? this.allowIndeterminateOutput,
      requireHumanReviewFlags:
          requireHumanReviewFlags ?? this.requireHumanReviewFlags,
      blockWithoutMinimumInputs:
          blockWithoutMinimumInputs ?? this.blockWithoutMinimumInputs,
      confidenceCapRequired:
          confidenceCapRequired ?? this.confidenceCapRequired,
    );
  }
}

class BloodstainProviderPolicy {
  final String forcedProvider;
  final bool requiresImageCapableProvider;
  final bool supportsUserModelSelection;
  final String modelSource;
  final String reason;

  const BloodstainProviderPolicy({
    required this.forcedProvider,
    required this.requiresImageCapableProvider,
    required this.supportsUserModelSelection,
    required this.modelSource,
    required this.reason,
  });

  factory BloodstainProviderPolicy.fromJson(Map<String, dynamic> json) {
    return BloodstainProviderPolicy(
      forcedProvider: json['forced_provider'] as String? ?? 'openai',
      requiresImageCapableProvider:
          json['requires_image_capable_provider'] as bool? ?? true,
      supportsUserModelSelection:
          json['supports_user_model_selection'] as bool? ?? true,
      modelSource: json['model_source'] as String? ?? 'provider_settings',
      reason: json['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'forced_provider': forcedProvider,
    'requires_image_capable_provider': requiresImageCapableProvider,
    'supports_user_model_selection': supportsUserModelSelection,
    'model_source': modelSource,
    'reason': reason,
  };

  BloodstainProviderPolicy copyWith({
    String? forcedProvider,
    bool? requiresImageCapableProvider,
    bool? supportsUserModelSelection,
    String? modelSource,
    String? reason,
  }) {
    return BloodstainProviderPolicy(
      forcedProvider: forcedProvider ?? this.forcedProvider,
      requiresImageCapableProvider:
          requiresImageCapableProvider ?? this.requiresImageCapableProvider,
      supportsUserModelSelection:
          supportsUserModelSelection ?? this.supportsUserModelSelection,
      modelSource: modelSource ?? this.modelSource,
      reason: reason ?? this.reason,
    );
  }
}

class BloodstainLinkedAssets {
  final String knowledgeBase;
  final String responseTemplates;
  final String uiMessages;
  final String glossary;
  final String analysisLevels;

  const BloodstainLinkedAssets({
    required this.knowledgeBase,
    required this.responseTemplates,
    required this.uiMessages,
    this.glossary = '',
    this.analysisLevels = '',
  });

  factory BloodstainLinkedAssets.fromJson(Map<String, dynamic> json) {
    return BloodstainLinkedAssets(
      knowledgeBase: json['knowledge_base'] as String? ?? '',
      responseTemplates: json['response_templates'] as String? ?? '',
      uiMessages: json['ui_messages'] as String? ?? '',
      glossary: json['glossary'] as String? ?? '',
      analysisLevels: json['analysis_levels'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'knowledge_base': knowledgeBase,
    'response_templates': responseTemplates,
    'ui_messages': uiMessages,
    'glossary': glossary,
    'analysis_levels': analysisLevels,
  };

  Map<String, String> toAssetMap() => {
    'knowledge_base': knowledgeBase,
    'response_templates': responseTemplates,
    'ui_messages': uiMessages,
    'glossary': glossary,
    'analysis_levels': analysisLevels,
  };

  BloodstainLinkedAssets copyWith({
    String? knowledgeBase,
    String? responseTemplates,
    String? uiMessages,
    String? glossary,
    String? analysisLevels,
  }) {
    return BloodstainLinkedAssets(
      knowledgeBase: knowledgeBase ?? this.knowledgeBase,
      responseTemplates: responseTemplates ?? this.responseTemplates,
      uiMessages: uiMessages ?? this.uiMessages,
      glossary: glossary ?? this.glossary,
      analysisLevels: analysisLevels ?? this.analysisLevels,
    );
  }
}

class BloodstainImplementationNotes {
  final String goal;
  final List<String> recommendedUsage;

  const BloodstainImplementationNotes({
    required this.goal,
    required this.recommendedUsage,
  });

  factory BloodstainImplementationNotes.fromJson(Map<String, dynamic> json) {
    final usage = json['recommended_usage'] as List<dynamic>? ?? const [];
    return BloodstainImplementationNotes(
      goal: json['goal'] as String? ?? '',
      recommendedUsage: usage.map((item) => item.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'goal': goal,
    'recommended_usage': recommendedUsage,
  };

  BloodstainImplementationNotes copyWith({
    String? goal,
    List<String>? recommendedUsage,
  }) {
    return BloodstainImplementationNotes(
      goal: goal ?? this.goal,
      recommendedUsage: recommendedUsage ?? this.recommendedUsage,
    );
  }
}

class BloodstainFeatureConfig {
  final String id;
  final int version;
  final String status;
  final BloodstainFeatureMetadata feature;
  final BloodstainProviderPolicy providerPolicy;
  final BloodstainFeatureBehavior behavior;
  final BloodstainLinkedAssets linkedAssets;
  final Map<String, dynamic> outputContract;
  final List<String> loadOrder;
  final BloodstainImplementationNotes implementationNotes;

  const BloodstainFeatureConfig({
    required this.id,
    required this.version,
    required this.status,
    required this.feature,
    required this.providerPolicy,
    required this.behavior,
    required this.linkedAssets,
    required this.outputContract,
    required this.loadOrder,
    required this.implementationNotes,
  });

  factory BloodstainFeatureConfig.fromJson(Map<String, dynamic> json) {
    final loadOrder = json['load_order'] as List<dynamic>? ?? const [];
    return BloodstainFeatureConfig(
      id: json['id'] as String? ?? '',
      version: json['version'] as int? ?? 1,
      status: json['status'] as String? ?? '',
      feature: BloodstainFeatureMetadata.fromJson(
        json['feature'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      providerPolicy: BloodstainProviderPolicy.fromJson(
        json['provider_policy'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      behavior: BloodstainFeatureBehavior.fromJson(
        json['behavior'] as Map<String, dynamic>? ?? const <String, dynamic>{},
      ),
      linkedAssets: BloodstainLinkedAssets.fromJson(
        json['linked_assets'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
      outputContract:
          json['output_contract'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
      loadOrder: loadOrder.map((item) => item.toString()).toList(),
      implementationNotes: BloodstainImplementationNotes.fromJson(
        json['implementation_notes'] as Map<String, dynamic>? ??
            const <String, dynamic>{},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'status': status,
    'feature': feature.toJson(),
    'provider_policy': providerPolicy.toJson(),
    'behavior': behavior.toJson(),
    'linked_assets': linkedAssets.toJson(),
    'output_contract': outputContract,
    'load_order': loadOrder,
    'implementation_notes': implementationNotes.toJson(),
  };

  BloodstainFeatureConfig copyWith({
    String? id,
    int? version,
    String? status,
    BloodstainFeatureMetadata? feature,
    BloodstainProviderPolicy? providerPolicy,
    BloodstainFeatureBehavior? behavior,
    BloodstainLinkedAssets? linkedAssets,
    Map<String, dynamic>? outputContract,
    List<String>? loadOrder,
    BloodstainImplementationNotes? implementationNotes,
  }) {
    return BloodstainFeatureConfig(
      id: id ?? this.id,
      version: version ?? this.version,
      status: status ?? this.status,
      feature: feature ?? this.feature,
      providerPolicy: providerPolicy ?? this.providerPolicy,
      behavior: behavior ?? this.behavior,
      linkedAssets: linkedAssets ?? this.linkedAssets,
      outputContract: outputContract ?? this.outputContract,
      loadOrder: loadOrder ?? this.loadOrder,
      implementationNotes: implementationNotes ?? this.implementationNotes,
    );
  }
}

class BloodstainFeatureBundle {
  final BloodstainFeatureConfig config;
  final Map<String, dynamic> knowledgeBase;
  final Map<String, dynamic> responseTemplates;
  final Map<String, dynamic> uiMessages;
  final Map<String, dynamic> glossary;
  final Map<String, dynamic> analysisLevels;
  final Map<String, Map<String, dynamic>> loadedAssets;

  const BloodstainFeatureBundle({
    required this.config,
    required this.knowledgeBase,
    required this.responseTemplates,
    required this.uiMessages,
    this.glossary = const <String, dynamic>{},
    this.analysisLevels = const <String, dynamic>{},
    required this.loadedAssets,
  });

  bool get conservativeMode => config.behavior.conservativeMode;
}
