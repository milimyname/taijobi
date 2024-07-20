/**
 * This file was @generated using pocketbase-typegen
 */
import type PocketBase from 'pocketbase';
import type { RecordService } from 'pocketbase';

export enum Collections {
	Feedbacks = 'feedbacks',
	Flashcard = 'flashcard',
	FlashcardBoxes = 'flashcardBoxes',
	FlashcardCollections = 'flashcardCollections',
	FlashcardCount = 'flashcardCount',
	Posts = 'posts',
	QuizProgress = 'quizProgress',
	Quizzes = 'quizzes',
	Searches = 'searches',
	Users = 'users',
}

// Alias types for improved usability
export type IsoDateString = string;
export type RecordIdString = string;
export type HTMLString = string;

// System fields
export type BaseSystemFields<T = never> = {
	id: RecordIdString;
	created: IsoDateString;
	updated: IsoDateString;
	collectionId: string;
	collectionName: Collections;
	expand?: T;
};

export type AuthSystemFields<T = never> = {
	email: string;
	emailVisibility: boolean;
	username: string;
	verified: boolean;
} & BaseSystemFields<T>;

// Record types for each collection

export type FeedbacksRecord = {
	description: string;
	device?: string;
	image?: string;
	name?: string;
	userId?: RecordIdString;
};

export enum FlashcardTypeOptions {
	'kanji' = 'kanji',
	'word' = 'word',
	'phrase' = 'phrase',
}

export enum FlashcardPartOfSpeechOptions {
	'verb' = 'verb',
	'adjective' = 'adjective',
	'unknown' = 'unknown',
}
export type FlashcardRecord = {
	flashcardBox?: RecordIdString;
	furigana?: string;
	meaning?: string;
	name?: string;
	notes?: string;
	partOfSpeech?: FlashcardPartOfSpeechOptions;
	romanji?: string;
	searches?: RecordIdString[];
	type?: FlashcardTypeOptions;
};

export type FlashcardBoxesRecord = {
	description?: string;
	flashcardCollection?: RecordIdString;
	flashcards?: RecordIdString[];
	kanjiCount?: number;
	name?: string;
	quizCount?: number;
	userId?: RecordIdString;
};

export enum FlashcardCollectionsTypeOptions {
	'original' = 'original',
	'custom' = 'custom',
}
export type FlashcardCollectionsRecord = {
	description?: string;
	flashcardBoxes?: RecordIdString[];
	name?: string;
	type?: FlashcardCollectionsTypeOptions;
	userId?: RecordIdString;
};

export type FlashcardCountRecord = {
	count?: number;
};

export type PostsRecord<Tcontent = unknown> = {
	content?: null | Tcontent;
	draft?: boolean;
	files?: string[];
	html?: HTMLString;
	title?: string;
	userId?: RecordIdString;
};

export type QuizProgressRecord<TprogressData = unknown> = {
	completed?: boolean;
	correctAnswers?: number;
	progressData?: null | TprogressData;
	quizId?: RecordIdString;
	total?: number;
	userId?: RecordIdString;
};

export enum QuizzesChoiceOptions {
	'E2' = '2',
	'E4' = '4',
}

export enum QuizzesTypeOptions {
	'meaning' = 'meaning',
	'name' = 'name',
	'onyomi' = 'onyomi',
	'kunyomi' = 'kunyomi',
}
export type QuizzesRecord<Tflashcards = unknown> = {
	choice?: QuizzesChoiceOptions;
	flashcardBox?: RecordIdString;
	flashcards?: null | Tflashcards;
	maxCount?: number;
	name?: string;
	score?: number;
	startCount?: number;
	timeLimit?: boolean;
	type?: QuizzesTypeOptions;
	userId?: RecordIdString;
};

export type SearchesRecord = {
	flashcard: RecordIdString;
	searchQuery?: string;
	user: RecordIdString;
};

export enum UsersRoleOptions {
	'user' = 'user',
	'editor' = 'editor',
	'admin' = 'admin',
}
export type UsersRecord = {
	avatar?: string;
	name?: string;
	oauth2ImageUrl?: string;
	role?: UsersRoleOptions[];
};

// Response types include system fields and match responses from the PocketBase API
export type FeedbacksResponse<Texpand = unknown> = Required<FeedbacksRecord> &
	BaseSystemFields<Texpand>;
export type FlashcardResponse<Texpand = unknown> = Required<FlashcardRecord> &
	BaseSystemFields<Texpand>;
export type FlashcardBoxesResponse<Texpand = unknown> = Required<FlashcardBoxesRecord> &
	BaseSystemFields<Texpand>;
export type FlashcardCollectionsResponse<Texpand = unknown> = Required<FlashcardCollectionsRecord> &
	BaseSystemFields<Texpand>;
export type FlashcardCountResponse<Texpand = unknown> = Required<FlashcardCountRecord> &
	BaseSystemFields<Texpand>;
export type PostsResponse<Tcontent = unknown, Texpand = unknown> = Required<PostsRecord<Tcontent>> &
	BaseSystemFields<Texpand>;
export type QuizProgressResponse<TprogressData = unknown, Texpand = unknown> = Required<
	QuizProgressRecord<TprogressData>
> &
	BaseSystemFields<Texpand>;
export type QuizzesResponse<Tflashcards = unknown, Texpand = unknown> = Required<
	QuizzesRecord<Tflashcards>
> &
	BaseSystemFields<Texpand>;
export type SearchesResponse<Texpand = unknown> = Required<SearchesRecord> &
	BaseSystemFields<Texpand>;
export type UsersResponse<Texpand = unknown> = Required<UsersRecord> & AuthSystemFields<Texpand>;

// Types containing all Records and Responses, useful for creating typing helper functions

export type CollectionRecords = {
	feedbacks: FeedbacksRecord;
	flashcard: FlashcardRecord;
	flashcardBoxes: FlashcardBoxesRecord;
	flashcardCollections: FlashcardCollectionsRecord;
	flashcardCount: FlashcardCountRecord;
	posts: PostsRecord;
	quizProgress: QuizProgressRecord;
	quizzes: QuizzesRecord;
	searches: SearchesRecord;
	users: UsersRecord;
};

export type CollectionResponses = {
	feedbacks: FeedbacksResponse;
	flashcard: FlashcardResponse;
	flashcardBoxes: FlashcardBoxesResponse;
	flashcardCollections: FlashcardCollectionsResponse;
	flashcardCount: FlashcardCountResponse;
	posts: PostsResponse;
	quizProgress: QuizProgressResponse;
	quizzes: QuizzesResponse;
	searches: SearchesResponse;
	users: UsersResponse;
};

// Type for usage with type asserted PocketBase instance
// https://github.com/pocketbase/js-sdk#specify-typescript-definitions

export type TypedPocketBase = PocketBase & {
	collection(idOrName: 'feedbacks'): RecordService<FeedbacksResponse>;
	collection(idOrName: 'flashcard'): RecordService<FlashcardResponse>;
	collection(idOrName: 'flashcardBoxes'): RecordService<FlashcardBoxesResponse>;
	collection(idOrName: 'flashcardCollections'): RecordService<FlashcardCollectionsResponse>;
	collection(idOrName: 'flashcardCount'): RecordService<FlashcardCountResponse>;
	collection(idOrName: 'posts'): RecordService<PostsResponse>;
	collection(idOrName: 'quizProgress'): RecordService<QuizProgressResponse>;
	collection(idOrName: 'quizzes'): RecordService<QuizzesResponse>;
	collection(idOrName: 'searches'): RecordService<SearchesResponse>;
	collection(idOrName: 'users'): RecordService<UsersResponse>;
};
