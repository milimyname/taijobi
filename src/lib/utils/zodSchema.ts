import { z } from 'zod';

export const loginSchema = z.object({
	email: z.string().min(3).max(32),
	password: z.string().min(8).max(32)
});

export const signupSchema = z.object({
	email: z.string().email(),
	password: z.string().min(8).max(32),
	passwordConfirm: z.string().min(8).max(32)
});

export const profileData = z.object({
	username: z.string().min(3).max(32).optional(),
	email: z.string().email().optional(),
	avatar: z.string().url().optional()
});

export const flashcardSchema = z.object({
	name: z.string(),
	meaning: z.string().optional(),
	type: z.string(),
	notes: z.string().optional(),
	romanji: z.string().optional(),
	flashcardsId: z.string().optional(),
	id: z.string().optional()
});

export const flashcardsSchema = z.object({
	name: z.string().max(25),
	description: z.string().max(100).optional(),
	id: z.string().optional()
});

export const feedbacksSchema = z.object({
	name: z.string(),
	description: z.string().max(1000),
	device: z.string(),
	userId: z.string()
});

export const quizSchema = z.object({
	name: z.string(),
	choice: z.string().default('2'),
	type: z.string().default('name'),
	maxCount: z.number().default(20),
	startCount: z.number().default(1),
	score: z.number().default(0),
	flashcardsId: z.string(),
	userId: z.string(),
	timeLimit: z.boolean().default(false),
	id: z.string().optional(),
	flashcards: z.string().optional()
});

export const quizProgressSchema = z.object({
	progressData: z.string(),
	quizId: z.string(),
	userId: z.string()
});
