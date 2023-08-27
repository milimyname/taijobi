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
	flashcards_id: z.string().optional()
});

export const flashcardsSchema = z.object({
	name: z.string().max(25),
	description: z.string().max(100).optional(),
	id: z.string().optional(),
	user_id: z.string()
});

export const feedbacksSchema = z.object({
	name: z.string(),
	message: z.string().max(1000),
	url: z.string().max(100).optional(),
	device: z.string()
});
