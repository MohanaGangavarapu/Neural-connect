import connectMongo from './config/mongo_pool.js';
import Word from './models/Word.js';
import { processWordNLP } from './services/nlp.service.js';

const initialWords = [
  'resilient',
  'ephemeral',
  'serendipity',
  'eloquent',
  'ubiquitous',
  'meticulous',
  'pragmatic',
  'tenacious',
  'audacious',
  'benevolent',
  'curious',
  'adapt',
  'beautiful',
  'exceptional',
  'stagnate'
];

export const seedDatabaseWords = async () => {
  await connectMongo();
  console.log('🌱 Starting vocabulary seeding into MongoDB...');

  for (const wordText of initialWords) {
    const existing = await Word.findOne({ word: wordText });
    if (!existing) {
      console.log(`Processing & inserting word: "${wordText}"...`);
      try {
        const nlpData = await processWordNLP(wordText);
        const newWord = new Word({
          word: nlpData.word || wordText,
          partOfSpeech: nlpData.partOfSpeech || 'noun',
          definition: nlpData.definition || 'A seeded vocabulary word.',
          exampleSentence: nlpData.exampleSentence || `Example sentence for ${wordText}.`,
          meanings: nlpData.meanings || [],
          abbreviations: nlpData.abbreviations || [],
          synonyms: nlpData.synonyms || [],
          antonyms: nlpData.antonyms || [],
          hypernyms: nlpData.hypernyms || [],
          hyponyms: nlpData.hyponyms || [],
          meronyms: nlpData.meronyms || [],
          holonyms: nlpData.holonyms || [],
          relatedTerms: nlpData.relatedTerms || [],
          similarWords: nlpData.similarWords || [],
          homonyms: nlpData.homonyms || [],
          phonetic: nlpData.phonetic || '',
          embedding: nlpData.embedding || []
        });
        await newWord.save();
        console.log(`✅ Saved: "${wordText}"`);
      } catch (err) {
        console.error(`Failed to process "${wordText}": ${err.message}`);
      }
    } else {
      console.log(`Word "${wordText}" already exists in DB.`);
    }
  }

  const finalCount = await Word.countDocuments();
  console.log(`🎉 Seeding complete! Total words in database: ${finalCount}`);
};

seedDatabaseWords().then(() => process.exit(0)).catch(err => {
  console.error('Seeding error:', err);
  process.exit(1);
});
