#ifndef UNZIPPY_CARCHIVE_SHIM_H
#define UNZIPPY_CARCHIVE_SHIM_H

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>
#include <time.h>

/*
 * Minimal hand-written bindings for the libarchive that ships with macOS.
 * Apple does not publish the headers, but the library is present in the
 * shared cache and in the SDK stub, so declaring the stable public ABI
 * here keeps the app tiny (no vendored libarchive, no external tools).
 */

struct archive;
struct archive_entry;

typedef int64_t la_int64_t;

struct archive *archive_read_new(void);
int archive_read_support_filter_all(struct archive *);
int archive_read_support_filter_gzip(struct archive *);
int archive_read_support_format_all(struct archive *);
int archive_read_support_format_raw(struct archive *);
int archive_read_support_format_empty(struct archive *);
int archive_read_open_filename(struct archive *, const char *filename, size_t block_size);
int archive_read_open_fd(struct archive *, int fd, size_t block_size);
int archive_read_next_header(struct archive *, struct archive_entry **);
la_int64_t archive_read_data(struct archive *, void *buff, size_t size);
int archive_read_data_block(struct archive *, const void **buff, size_t *size, la_int64_t *offset);
int archive_read_data_skip(struct archive *);
int archive_read_add_passphrase(struct archive *, const char *passphrase);
int archive_read_set_options(struct archive *, const char *options);
int archive_read_has_encrypted_entries(struct archive *);
int archive_read_close(struct archive *);
int archive_read_free(struct archive *);
const char *archive_error_string(struct archive *);
int archive_errno(struct archive *);
const char *archive_format_name(struct archive *);
int archive_format(struct archive *);
const char *archive_filter_name(struct archive *, int code);
int archive_filter_code(struct archive *, int code);
int archive_filter_count(struct archive *);

const char *archive_entry_pathname(struct archive_entry *);
const char *archive_entry_pathname_utf8(struct archive_entry *);
la_int64_t archive_entry_size(struct archive_entry *);
int archive_entry_size_is_set(struct archive_entry *);
time_t archive_entry_mtime(struct archive_entry *);
int archive_entry_mtime_is_set(struct archive_entry *);
mode_t archive_entry_mode(struct archive_entry *);
mode_t archive_entry_filetype(struct archive_entry *);
mode_t archive_entry_perm(struct archive_entry *);
la_int64_t archive_entry_uid(struct archive_entry *);
la_int64_t archive_entry_gid(struct archive_entry *);
const char *archive_entry_symlink(struct archive_entry *);
const char *archive_entry_symlink_utf8(struct archive_entry *);
const char *archive_entry_hardlink(struct archive_entry *);
const char *archive_entry_hardlink_utf8(struct archive_entry *);

struct archive *archive_write_new(void);
int archive_write_set_format_zip(struct archive *);
int archive_write_set_format_7zip(struct archive *);
int archive_write_set_format_pax_restricted(struct archive *);
int archive_write_add_filter_none(struct archive *);
int archive_write_add_filter_gzip(struct archive *);
int archive_write_set_options(struct archive *, const char *);
int archive_write_set_format_option(struct archive *, const char *, const char *, const char *);
int archive_write_set_passphrase(struct archive *, const char *);
int archive_write_open_filename(struct archive *, const char *);
struct archive_entry *archive_entry_new(void);
void archive_entry_free(struct archive_entry *);
void archive_entry_set_pathname_utf8(struct archive_entry *, const char *);
void archive_entry_set_size(struct archive_entry *, la_int64_t);
void archive_entry_set_filetype(struct archive_entry *, mode_t);
void archive_entry_set_perm(struct archive_entry *, mode_t);
void archive_entry_set_mtime(struct archive_entry *, time_t, long);
void archive_entry_set_atime(struct archive_entry *, time_t, long);
void archive_entry_set_symlink_utf8(struct archive_entry *, const char *);
int archive_write_header(struct archive *, struct archive_entry *);
ssize_t archive_write_data(struct archive *, const void *, size_t);
int archive_write_close(struct archive *);
int archive_write_free(struct archive *);
const char *archive_write_error_string(struct archive *);

#endif
