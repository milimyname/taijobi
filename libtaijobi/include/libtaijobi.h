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

/* Phase 3.5 — CSV Import/Export + Anki .apkg */
int32_t     hanzi_import_csv(const void *csv, size_t csv_len,
                              const void *name, size_t name_len);
const void *hanzi_export_csv(void);
int32_t     hanzi_import_apkg(const void *apkg, size_t apkg_len,
                               const void *name, size_t name_len);

/* Phase 5.1 — Stats */
const void *hanzi_get_stats(uint32_t days);

/* Reading mode */
int32_t     hanzi_mark_read(const void *id, size_t len);
const void *hanzi_get_unread_cards(const void *filter, size_t filter_len, uint32_t limit);
int32_t     hanzi_get_unread_count(const void *filter, size_t filter_len);

/* Chinese data — on-demand loading */
void   *hanzi_persist_alloc(size_t len);
int32_t hanzi_load_cedict(const void *ptr, size_t len);
int32_t hanzi_load_decomp(const void *ptr, size_t len);
int32_t hanzi_load_strokes(const void *ptr, size_t len);
int32_t hanzi_chinese_data_loaded(void);

/* WASM-only: OPFS persistence helpers */
void   *hanzi_db_ptr(void);
int32_t hanzi_db_size(void);
int32_t hanzi_db_load(const void *data, int32_t len);

#ifdef __cplusplus
}
#endif

#endif /* LIBTAIJOBI_H */
