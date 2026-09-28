//
//  AsoAiModels.swift
//  seenlab
//
//  The results of the two AI jobs the ASO screen shows: the listing proposal (`suggest`) and the review
//  analysis (`reviews_insights`). Both are written by a model, so each field decodes on its own — one
//  field in an unexpected shape leaves that field empty instead of hiding the whole result.
//

import Foundation

extension KeyedDecodingContainer {
    /// Decodes the key if it is present and has the expected shape, nil otherwise.
    func asoLenient<T: Decodable>(_ key: Key) -> T? { (try? decodeIfPresent(T.self, forKey: key)) ?? nil }
}

/// A model's name and token count, attached to every AI result.
struct AsoAiMeta: Decodable, Hashable {
    let model: String?
    let usage: Usage?

    struct Usage: Decodable, Hashable { let totalTokens: Double? }
}

// MARK: - Listing proposal

/// `result` of a `suggest` job.
struct AsoSuggestionResult: Decodable {
    let country: String?
    let platform: String?
    let generatedAt: String?
    let ai: AsoAiMeta?
    let suggestion: AsoSuggestion?

    enum CodingKeys: String, CodingKey { case country, platform, generatedAt, ai, suggestion }

    init(from decoder: Decoder) throws {
        // A job that has not finished can carry `[]` instead of an object.
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else {
            country = nil; platform = nil; generatedAt = nil; ai = nil; suggestion = nil; return
        }
        country = c.asoLenient(.country)
        platform = c.asoLenient(.platform)
        generatedAt = c.asoLenient(.generatedAt)
        ai = c.asoLenient(.ai)
        suggestion = c.asoLenient(.suggestion)
    }
}

struct AsoSuggestion: Decodable {
    let summary: String?
    let title: Field?
    let subtitle: Field?
    let keywordField: Field?
    let description: Field?
    let alternatives: [Alternative]
    let quickWins: [String]
    let keywordsToAdd: [Term]
    let keywordsToDrop: [Term]
    let descriptionTips: [String]
    let secondaryLocalizations: [Localization]

    /// One proposed field, with the model's reasoning and its length against the store limit.
    struct Field: Decodable, Hashable {
        let text: String?
        let rationale: String?
        let length: Int?
        let max: Int?
        let ok: Bool?
    }

    struct Alternative: Decodable, Hashable {
        let title: String?
        let subtitle: String?
    }

    struct Term: Decodable, Hashable {
        let term: String
        let why: String?
    }

    struct Localization: Decodable, Hashable {
        let locale: String?
        let why: String?
        let keywordField: String?
        let subtitle: String?
    }

    enum CodingKeys: String, CodingKey {
        case summary, title, subtitle, keywordField, description, alternatives, quickWins, keywordsToAdd, keywordsToDrop, descriptionTips, secondaryLocalizations
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        summary = c.asoLenient(.summary)
        title = c.asoLenient(.title)
        subtitle = c.asoLenient(.subtitle)
        keywordField = c.asoLenient(.keywordField)
        description = c.asoLenient(.description)
        alternatives = c.asoLenient(.alternatives) ?? []
        quickWins = c.asoLenient(.quickWins) ?? []
        keywordsToAdd = c.asoLenient(.keywordsToAdd) ?? []
        keywordsToDrop = c.asoLenient(.keywordsToDrop) ?? []
        descriptionTips = c.asoLenient(.descriptionTips) ?? []
        secondaryLocalizations = c.asoLenient(.secondaryLocalizations) ?? []
    }
}

// MARK: - Review analysis

/// `result` of a `reviews_insights` job.
struct AsoReviewsInsightsResult: Decodable {
    let generatedAt: String?
    let reviewsUsed: Double?
    let ai: AsoAiMeta?
    let insights: AsoReviewsInsights?

    enum CodingKeys: String, CodingKey { case generatedAt, reviewsUsed, ai, insights }

    init(from decoder: Decoder) throws {
        guard let c = try? decoder.container(keyedBy: CodingKeys.self) else {
            generatedAt = nil; reviewsUsed = nil; ai = nil; insights = nil; return
        }
        generatedAt = c.asoLenient(.generatedAt)
        reviewsUsed = c.asoLenient(.reviewsUsed)
        ai = c.asoLenient(.ai)
        insights = c.asoLenient(.insights)
    }
}

struct AsoReviewsInsights: Decodable {
    let marketSummary: String?
    let unmetNeeds: [Need]
    let listingWords: [Word]
    let objectionsToPreempt: [String]
    let featureIdeas: [Idea]
    let ownAppNotes: String?

    struct Need: Decodable, Hashable { let need: String?; let evidence: String?; let howYouCanWin: String? }
    struct Word: Decodable, Hashable { let word: String; let why: String? }
    struct Idea: Decodable, Hashable { let idea: String?; let effort: String?; let why: String? }

    enum CodingKeys: String, CodingKey { case marketSummary, unmetNeeds, listingWords, objectionsToPreempt, featureIdeas, ownAppNotes }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        marketSummary = c.asoLenient(.marketSummary)
        unmetNeeds = c.asoLenient(.unmetNeeds) ?? []
        listingWords = c.asoLenient(.listingWords) ?? []
        objectionsToPreempt = c.asoLenient(.objectionsToPreempt) ?? []
        featureIdeas = c.asoLenient(.featureIdeas) ?? []
        ownAppNotes = c.asoLenient(.ownAppNotes)
    }

    var isEmpty: Bool { (marketSummary ?? "").isEmpty && unmetNeeds.isEmpty && listingWords.isEmpty && objectionsToPreempt.isEmpty && featureIdeas.isEmpty }
}
