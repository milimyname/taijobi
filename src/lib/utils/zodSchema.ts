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

export const flashCard = z.object({
	user_id: z.string().optional(),
	word: z.string().optional(),
	translation: z.string().optional(),
	type: z.string().optional()
});
