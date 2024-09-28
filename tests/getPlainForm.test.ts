import { getPlainForm } from '$lib/utils/getPlainForm';
import { expect, test } from 'vitest';

test('getPlainForm', () => {
	expect(getPlainForm('寝ます')).toBe('寝る');
	expect(getPlainForm('見ます')).toBe('見る');
	expect(getPlainForm('食べます')).toBe('食べる');
	expect(getPlainForm('走ります')).toBe('走る');
	expect(getPlainForm('借ります')).toBe('借りる');
	expect(getPlainForm('切ります')).toBe('切る');
	expect(getPlainForm('帰ります')).toBe('帰る');
	expect(getPlainForm('起きます')).toBe('起きる');
	expect(getPlainForm('開けます')).toBe('開ける');
	expect(getPlainForm('教えます')).toBe('教える');
});
