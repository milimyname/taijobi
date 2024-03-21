import { z } from 'zod';

export const loginSchema = z.object({
	email: z.string().min(3).max(32),
	password: z.string().min(8).max(32)
});

export type LoginSchema = typeof loginSchema;

export const signupSchema = z.object({
	email: z.string().email(),
	password: z.string().min(8).max(32),
	confirmPassword: z.string().min(8).max(32)
});

export type SignupSchema = typeof signupSchema;

export const resetPasswordSchema = z.object({
	email: z.string().min(3).max(32)
});

export type ResetPasswordSchema = typeof resetPasswordSchema;

export const profileData = z.object({
	username: z.string().min(3).max(32).optional(),
	email: z.string().email().optional(),
	avatar: z.string().url().optional()
});

export type ProfileData = typeof profileData;

export const flashcardSchema = z.object({
	name: z.string().nonempty({ message: 'Name is required.' }),
	meaning: z.string().optional(),
	type: z.string().nonempty({ message: 'Type is required.' }),
	notes: z.string().optional(),
	romanji: z.string().optional(),
	furigana: z.string().optional(),
	flashcardBox: z.string().optional(),
	id: z.string().optional()
});

export type FlashcardSchema = typeof flashcardSchema;

export const flashcardCollectionSchema = z.object({
	name: z.string().max(25),
	description: z.string().max(100).optional(),
	type: z.string().optional(),
	id: z.string().optional(),
	flashcardCollection: z.string().optional()
});

export type FlashcardCollectionSchema = typeof flashcardCollectionSchema;

export const feedbackSchema = z.object({
	name: z.string().nonempty({ message: 'Name is required.' }),
	description: z.string().max(1000),
	device: z.string().optional(),
	userId: z.string(),
	image: z.string().optional(),
	id: z.string().optional()
});

export type FeedbackSchema = typeof feedbackSchema;

export const quizSchema = z.object({
	name: z.string().nonempty({ message: 'Name is required.' }),
	choice: z.string().default('2'),
	type: z.string().default('name'),
	maxCount: z.number().default(10),
	startCount: z.number().default(1),
	score: z.number().default(0),
	flashcardBox: z.string(),
	userId: z.string(),
	timeLimit: z.boolean().default(false),
	id: z.string().optional(),
	flashcards: z.string().optional(),
	selectedQuizItems: z.string().optional()
});

export type QuizSchema = typeof quizSchema;

export const quizProgressSchema = z.object({
	progressData: z.string(),
	quizId: z.string(),
	userId: z.string()
});

export type QuizProgressSchema = typeof quizProgressSchema;

export const openaiSchema = z.object({
	input: z.string().min(1, { message: 'Input is required.' }),
	type: z.string().min(1, { message: 'Type is required.' })
});
