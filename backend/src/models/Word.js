import mongoose from 'mongoose';

const wordSchema = new mongoose.Schema(
  {
    word: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    partOfSpeech: {
      type: String,
      required: true,
      lowercase: true,
      trim: true,
    },
    definition: {
      type: String,
      required: true,
      trim: true,
    },
    exampleSentence: {
      type: String,
      trim: true,
      default: '',
    },
    meanings: {
      type: [String],
      default: [],
    },
    abbreviations: {
      type: [String],
      default: [],
    },
    synonyms: {
      type: [String],
      default: [],
    },
    antonyms: {
      type: [String],
      default: [],
    },
    hypernyms: {
      type: [String],
      default: [],
    },
    hyponyms: {
      type: [String],
      default: [],
    },
    meronyms: {
      type: [String],
      default: [],
    },
    holonyms: {
      type: [String],
      default: [],
    },
    relatedTerms: {
      type: [String],
      default: [],
    },
    similarWords: {
      type: [String],
      default: [],
    },
    homonyms: {
      type: [String],
      default: [],
    },
    phonetic: {
      type: String,
      trim: true,
      default: '',
    },
    embedding: {
      type: [Number],
      required: true,
      validate: {
        validator: function (v) {
          return Array.isArray(v) && v.length > 0;
        },
        message: 'Word embedding matrix must not be empty.'
      }
    }
  },
  { timestamps: true }
);

export default mongoose.model('Word', wordSchema);
