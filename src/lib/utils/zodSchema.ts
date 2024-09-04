import { z } from 'zod';

export const loginSchema = z.object({
	email: z.string().min(3).max(32),
	password: z.string().min(8).max(32),
});

export type LoginSchema = typeof loginSchema;

export const signupSchema = z.object({
	email: z.string().email(),
	password: z.string().min(8).max(32),
	passwordConfirm: z.string().min(8).max(32),
});

export type SignupSchema = typeof signupSchema;

export const resetPasswordSchema = z.object({
	email: z.string().min(3).max(32),
});

export type ResetPasswordSchema = typeof resetPasswordSchema;

export const profileDataSchema = z.object({
	username: z.string().min(3).max(32).optional(),
	email: z.string().email().optional(),
	avatar: z.string().url().optional(),
});

export type ProfileDataSchema = typeof profileDataSchema;

export const flashcardSchema = z.object({
	name: z.string().nonempty({ message: 'Name is required.' }),
	meaning: z.string().optional(),
	type: z.string().nonempty({ message: 'Type is required.' }),
	notes: z.string().optional(),
	romaji: z.string().optional(),
	furigana: z.string().optional(),
	partOfSpeech: z.string().optional(),
	user: z.string().optional(),
	flashcardBox: z.string().optional(),
	id: z.string().optional(),
});

export type FlashcardSchema = typeof flashcardSchema;

export const flashcardCollectionSchema = z.object({
	name: z.string().min(1).max(25),
	description: z.string().max(100).optional(),
	type: z.string().optional(),
	id: z.string().optional(), // it is used as flashcardBox id in search page
	kanjiCount: z.number().optional(),
	quizCount: z.number().optional(),
	flashcardCollection: z.string().optional(),
});

export type FlashcardCollectionSchema = typeof flashcardCollectionSchema;

// Refine this scame if collectionName is new-colletion,
// then collectionName is required
export const searchCollectionSchema = z
	.object({
		boxId: z.string().min(1),
		collectionId: z.string().min(1),
		boxName: z.string(),
		collectionName: z.string(),
		flashcards: z.array(
			z.object({
				id: z.string(),
				name: z.string(),
				type: z.string().optional(),
				meaning: z.string().optional(),
				romaji: z.string().optional(),
				furigana: z.string().optional(),
				partOfSpeech: z.string().optional(),
			}),
		),
	})
	.refine(
		(data) => {
			if (data.collectionId === '' || data.boxId === '') return false;
			if (data.collectionId === '' && data.boxId === 'new-box') return false;
			if (
				data.collectionId === 'new-collection' &&
				data.boxId === 'new-box' &&
				data.collectionName === '' &&
				data.boxName === ''
			)
				return false;
			if (data.collectionId === 'new-collection' && data.collectionName === '') return false;
			if (data.boxId === 'new-box' && data.boxName === '') return false;
			if (data.collectionId !== 'new-collection' && data.boxId === 'new-box' && data.boxName === '')
				return false;

			return true;
		},
		{
			message: 'Please provide all required fields.',
			path: ['boxName'],
		},
	);

export type SearchCollectionSchema = typeof searchCollectionSchema;

export const conjugationFormSchema = z.object({
	id: z.string(),
	name: z.string(),
	flashcards: z.array(
		z.object({
			id: z.string(),
			name: z.string(),
			type: z.string().optional(),
			meaning: z.string().optional(),
			partOfSpeech: z.string().optional(),
		}),
	),
	settings: z.array(z.string()),
	userId: z.string().optional(),
});

export type ConjugationFormSchema = typeof conjugationFormSchema;

export const feedbackSchema = z.object({
	description: z.string().max(1000),
	userId: z.string(),
	image: z.string().optional(),
	id: z.string().optional(),
});

export type FeedbackSchema = typeof feedbackSchema;

export const quizSchema = z.object({
	name: z.string().nonempty({ message: 'Name is required.' }),
	choice: z.string().default('2'),
	type: z.string().default('name'),
	maxCount: z.string().default('10'),
	startCount: z
		.string()
		.default('1')
		.refine((data) => parseInt(data) >= 1, {
			message: 'Start count cannot be less than 1.',
		}),
	score: z.number().default(0),
	flashcardBox: z.string(),
	userId: z.string(),
	timeLimit: z.boolean().default(false),
	id: z.string().optional(),
	flashcards: z.string().optional(),
	selectedQuizItems: z.string().optional().default(''),
});

export type QuizSchema = typeof quizSchema;

export const quizProgressSchema = z.object({
	progressData: z.string(),
	quizId: z.string(),
	userId: z.string(),
});

export type QuizProgressSchema = typeof quizProgressSchema;

export const openaiSchema = z.object({
	input: z.string().min(1, { message: 'Input is required.' }),
	type: z.string().min(1, { message: 'Type is required.' }),
});
