class AiSummary {
  final String summary;
  final List<String> strengths;
  final String audience;
  final String mood;
  final List<String> similarTo;

  const AiSummary({required this.summary, required this.strengths, required this.audience, required this.mood, required this.similarTo});

  factory AiSummary.empty() => const AiSummary(summary: '', strengths: [], audience: '', mood: '', similarTo: []);
}

class WorthWatching {
  final String verdict;
  final double score;
  final String reason;
  final String forWhom;
  final String againstWhom;
  final String watchIf;
  final String skipIf;

  const WorthWatching({required this.verdict, required this.score, required this.reason, required this.forWhom, required this.againstWhom, required this.watchIf, required this.skipIf});

  factory WorthWatching.empty() => const WorthWatching(verdict: 'يعتمد على الذوق', score: 0, reason: '', forWhom: '', againstWhom: '', watchIf: '', skipIf: '');
}

class MoodResult {
  final String detectedMood;
  final double confidence;
  final String explanation;
  final List<String> genres;
  final List<String> avoidGenres;
  final List<String> movies;
  final List<String> anime;

  const MoodResult({required this.detectedMood, required this.confidence, required this.explanation, required this.genres, required this.avoidGenres, required this.movies, required this.anime});

  factory MoodResult.empty() => const MoodResult(detectedMood: '', confidence: 0, explanation: '', genres: [], avoidGenres: [], movies: [], anime: []);
}

class TasteAnalysis {
  final String personality;
  final List<String> patterns;
  final String strengths;
  final String blindSpots;
  final List<String> topGenres;
  final List<String> avoidedGenres;
  final String recommendation;
  final String archetype;

  const TasteAnalysis({required this.personality, required this.patterns, required this.strengths, required this.blindSpots, required this.topGenres, required this.avoidedGenres, required this.recommendation, required this.archetype});

  factory TasteAnalysis.empty() => const TasteAnalysis(personality: '', patterns: [], strengths: '', blindSpots: '', topGenres: [], avoidedGenres: [], recommendation: '', archetype: '');
}

class PosterAnalysis {
  final String type;
  final List<String> genres;
  final String audience;
  final String mood;
  final List<String> colors;
  final String colorMeaning;
  final List<String> symbols;
  final String verdict;

  const PosterAnalysis({required this.type, required this.genres, required this.audience, required this.mood, required this.colors, required this.colorMeaning, required this.symbols, required this.verdict});

  factory PosterAnalysis.empty() => const PosterAnalysis(type: '', genres: [], audience: '', mood: '', colors: [], colorMeaning: '', symbols: [], verdict: '');
}
