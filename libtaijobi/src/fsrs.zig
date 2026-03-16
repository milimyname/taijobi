// FSRS-5 scheduler — pure Zig implementation.
// Default parameters from: https://github.com/open-spaced-repetition/fsrs-rs

const std = @import("std");
const types = @import("types.zig");

const Rating = types.Rating;
const FSRSState = types.FSRSState;
const IntervalInfo = types.IntervalInfo;
const ScheduleOutput = types.ScheduleOutput;

// FSRS-5 default parameters (17 values)
const w = [17]f64{
    0.40255, 1.18385, 3.173,   15.69105, // w0-w3: initial stability per rating
    7.1949,  0.5345,  1.4604, // w4-w6: initial difficulty
    0.0046,  1.54575, 0.1192, 0.5058, // w7-w10: stability after success
    1.86210, 0.1597,  0.4200, // w11-w13: stability after forget
    2.18940, 0.0275,  0.4606, // w14-w16: short-term stability
};

const DECAY: f64 = -0.5;
const FACTOR: f64 = 19.0 / 81.0; // (0.9^(1/DECAY) - 1)
const DEFAULT_RETENTION: f64 = 0.9;

/// Probability of recall after `elapsed_days` with given `stability`.
pub fn retrievability(elapsed_days: f64, stability: f64) f64 {
    if (stability <= 0.0) return 0.0;
    return std.math.pow(f64, 1.0 + FACTOR * elapsed_days / stability, DECAY);
}

/// Initial stability for a new card, based on first rating.
fn initialStability(rating: Rating) f64 {
    return w[@as(usize, @intFromEnum(rating)) - 1];
}

/// Initial difficulty for a new card, based on first rating.
fn initialDifficulty(rating: Rating) f64 {
    const g: f64 = @floatFromInt(@intFromEnum(rating));
    const raw = w[4] - @exp(w[5] * (g - 1.0)) + 1.0;
    return clamp(raw, 1.0, 10.0);
}

/// Next difficulty after a review.
fn nextDifficulty(d: f64, rating: Rating) f64 {
    const g: f64 = @floatFromInt(@intFromEnum(rating));
    const delta = -w[6] * (g - 3.0);
    // Mean reversion toward initial difficulty
    const d_new = d + delta * (1.0 - (1.0 / (1.0 + @exp(-d + 5.0))));
    const init_d = initialDifficulty(Rating.easy);
    const reverted = w[7] * init_d + (1.0 - w[7]) * d_new;
    return clamp(reverted, 1.0, 10.0);
}

/// Next stability after a successful recall.
fn nextStabilitySuccess(d: f64, s: f64, r: f64, rating: Rating) f64 {
    const hard_bonus: f64 = if (rating == .hard) w[15] else 1.0;
    const easy_bonus: f64 = if (rating == .easy) w[16] else 1.0;
    return s * (1.0 + @exp(w[8]) *
        (11.0 - d) *
        std.math.pow(f64, s, -w[9]) *
        (@exp((1.0 - r) * w[10]) - 1.0) *
        hard_bonus * easy_bonus);
}

/// Next stability after a lapse (forgot the card).
fn nextStabilityForget(d: f64, s: f64, r: f64) f64 {
    return w[11] *
        std.math.pow(f64, d, -w[12]) *
        (std.math.pow(f64, s + 1.0, w[13]) - 1.0) *
        @exp((1.0 - r) * w[14]);
}

/// Convert stability to interval in days for desired retention.
fn nextInterval(stability: f64) f64 {
    if (stability <= 0.0) return 0.0;
    const interval = stability / FACTOR * (std.math.pow(f64, DEFAULT_RETENTION, 1.0 / DECAY) - 1.0);
    return @max(1.0, interval);
}

/// Compute intervals for all 4 ratings given current state and elapsed days.
pub fn schedule(state: FSRSState, elapsed_days: f64) ScheduleOutput {
    const is_new = state.reps == 0;
    const r = if (is_new) 0.0 else retrievability(elapsed_days, state.stability);

    var out: ScheduleOutput = undefined;
    const ratings = [_]Rating{ .again, .hard, .good, .easy };
    inline for (ratings) |rating| {
        const new_d = if (is_new) initialDifficulty(rating) else nextDifficulty(state.difficulty, rating);
        const new_s = if (is_new)
            initialStability(rating)
        else if (rating == .again)
            nextStabilityForget(state.difficulty, state.stability, r)
        else
            nextStabilitySuccess(state.difficulty, state.stability, r, rating);
        const interval = nextInterval(new_s);

        const info = IntervalInfo{
            .rating = rating,
            .interval_days = interval,
            .new_stability = new_s,
            .new_difficulty = new_d,
        };
        @field(out, @tagName(rating)) = info;
    }
    return out;
}

/// Apply a rating to a card, returning the new FSRS state.
pub fn review(state: FSRSState, rating: Rating, elapsed_days: f64) FSRSState {
    const is_new = state.reps == 0;
    const r = if (is_new) 0.0 else retrievability(elapsed_days, state.stability);

    const new_d = if (is_new) initialDifficulty(rating) else nextDifficulty(state.difficulty, rating);
    const new_s = if (is_new)
        initialStability(rating)
    else if (rating == .again)
        nextStabilityForget(state.difficulty, state.stability, r)
    else
        nextStabilitySuccess(state.difficulty, state.stability, r, rating);

    return .{
        .difficulty = new_d,
        .stability = new_s,
        .reps = state.reps + 1,
        .lapses = if (rating == .again) state.lapses + 1 else state.lapses,
    };
}

fn clamp(val: f64, lo: f64, hi: f64) f64 {
    return @max(lo, @min(hi, val));
}

// --- Tests ---

test "new card schedule produces increasing intervals" {
    const state = FSRSState{};
    const out = schedule(state, 0);
    try std.testing.expect(out.again.interval_days < out.hard.interval_days);
    try std.testing.expect(out.hard.interval_days < out.good.interval_days);
    try std.testing.expect(out.good.interval_days < out.easy.interval_days);
}

test "initial stability matches w[0..3]" {
    try std.testing.expectApproxEqAbs(w[0], initialStability(.again), 0.001);
    try std.testing.expectApproxEqAbs(w[1], initialStability(.hard), 0.001);
    try std.testing.expectApproxEqAbs(w[2], initialStability(.good), 0.001);
    try std.testing.expectApproxEqAbs(w[3], initialStability(.easy), 0.001);
}

test "review updates state correctly" {
    const state = FSRSState{};
    const after = review(state, .good, 0);
    try std.testing.expect(after.reps == 1);
    try std.testing.expect(after.stability > 0);
    try std.testing.expect(after.difficulty >= 1.0);
    try std.testing.expect(after.difficulty <= 10.0);
    try std.testing.expect(after.lapses == 0);
}

test "lapse increments lapse count" {
    const s1 = review(FSRSState{}, .good, 0);
    const s2 = review(s1, .again, 3.0);
    try std.testing.expect(s2.lapses == 1);
    try std.testing.expect(s2.reps == 2);
}

test "retrievability decays over time" {
    const r0 = retrievability(0, 10.0);
    const r5 = retrievability(5, 10.0);
    const r30 = retrievability(30, 10.0);
    try std.testing.expect(r0 > r5);
    try std.testing.expect(r5 > r30);
    try std.testing.expectApproxEqAbs(1.0, r0, 0.001);
}

test "zero stability returns zero retrievability" {
    try std.testing.expectApproxEqAbs(0.0, retrievability(5, 0.0), 0.001);
}
