#ifndef LIBTAIJOBI_H
#define LIBTAIJOBI_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Core lifecycle */
int32_t hanzi_init(const char *db_path);
void    hanzi_close(void);

/* Memory management (FBA) */
void   *hanzi_alloc(size_t len);
void    hanzi_free(void *ptr, size_t len);
void    hanzi_reset_alloc(void);

/* Error reporting — returns length-prefixed string or NULL */
const void *hanzi_get_error(void);

/* Review API — all return length-prefixed JSON or status codes */
const void *hanzi_get_due_cards(uint32_t limit);
int32_t     hanzi_get_due_count(void);
int32_t     hanzi_review_card(const void *id, size_t id_len, uint8_t rating);

/* Phase 1 — Lexicon + Dictionary */
const void *hanzi_add_word(const void *word, size_t len);
int32_t     hanzi_remove_word(const void *id, size_t len);
int32_t     hanzi_update_word(const void *id, size_t id_len,
                              const void *trans, size_t trans_len);
const void *hanzi_lookup(const void *query, size_t len);
const void *hanzi_get_lexicon(void);
const void *hanzi_get_drill_stats(void);

/* Phase 2 — Content Packs */
int32_t     hanzi_install_pack(const void *json, size_t len);
const void *hanzi_get_packs(void);
int32_t     hanzi_remove_pack(const void *id, size_t len);
const void *hanzi_get_lessons(const void *pack_id, size_t len);
const void *hanzi_get_vocabulary(const void *lesson_id, size_t len);
const void *hanzi_get_progress(const void *pack_id, size_t len);

/* Phase 3 — Deep Chinese */
const void *hanzi_decompose(const void *ch, size_t len);
const void *hanzi_get_strokes(const void *ch, size_t len);

/* WASM-only: OPFS persistence helpers */
void   *hanzi_db_ptr(void);
int32_t hanzi_db_size(void);
int32_t hanzi_db_load(const void *data, int32_t len);

#ifdef __cplusplus
}
#endif

#endif /* LIBTAIJOBI_H */
