/*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This software may be used and distributed according to the terms of the
 * GNU General Public License version 2.
 */

//! ------------
//! IMPORTANT!!!
//! ------------
//! Do not change the order of the fields! Changing the order of the fields
//! results in compatible but *not* identical serializations, so hashes will
//! change.
//! ------------
//! IMPORTANT!!!
//! ------------

namespace py3 eden.mononoke.mononoke_types

typedef binary Blake2 (rust.newtype, rust.type = "smallvec::SmallVec<[u8; 32]>")

// NB don't call the type bytes as py3 bindings don't like it
typedef binary (rust.type = "bytes::Bytes") binary_bytes

// Allow the hash type to change in the future.
union IdType {
  1: Blake2 Blake2,
} (rust.ord)

typedef IdType ChangesetId (rust.newtype)
typedef IdType ContentId (rust.newtype)
typedef IdType ContentChunkId (rust.newtype)
typedef IdType RawBundle2Id (rust.newtype)
typedef IdType FileUnodeId (rust.newtype)
typedef IdType ManifestUnodeId (rust.newtype)
typedef IdType DeletedManifestId(rust.newtype)
typedef IdType FsnodeId (rust.newtype)
typedef IdType SkeletonManifestId(rust.newtype)
typedef IdType MPathHash (rust.newtype)

typedef IdType ContentMetadataId (rust.newtype)
typedef IdType FastlogBatchId (rust.newtype)
typedef IdType BlameId (rust.newtype)
typedef IdType BlameV2Id (rust.newtype)

// mercurial_types defines Sha1, and it's most convenient to stick this in here.
// This can be moved away in the future if necessary. Could also be used for
// raw content sha1 (should this be separated?)
typedef binary Sha1 (rust.newtype, rust.type = "smallvec::SmallVec<[u8; 20]>")

// Other content alias types
typedef binary Sha256 (rust.newtype, rust.type = "smallvec::SmallVec<[u8; 32]>")
typedef binary GitSha1 (rust.newtype, rust.type = "smallvec::SmallVec<[u8; 20]>")

// A path in a repo is stored as a list of elements. This is so that the sort
// order of paths is the same as that of a tree traversal, so that deltas on
// manifests can be applied in a streaming way.
typedef binary MPathElement (rust.newtype, rust.type = "smallvec::SmallVec<[u8; 24]>")
typedef list<MPathElement> MPath (rust.newtype)

union RepoPath {
  # Thrift language doesn't support void here, so put a dummy bool
  1: bool RootPath,
  2: MPath DirectoryPath,
  3: MPath FilePath,
}

// Parent ordering
// ---------------
// "Ordered" parents means that behavior will change if the order of parents
// changes.
// Whether parents are ordered varies by source control system.
// * In Mercurial, parents are stored ordered and the UI is order-dependent,
//   but are hashed unordered.
// * In Git, parents are stored and hashed ordered and the UI is also order-
//   dependent.
// These data structures will store parents in ordered form, as presented by
// Mercurial. This does hypothetically mean that a single Mercurial changeset
// can map to two Mononoke changesets -- those cases are extremely unlikely
// in practice, and if they're deliberately constructed Mononoke will probably
// end up rejecting whatever comes later.

// Other notes:
// * This uses sorted sets and maps to ensure deterministic
//   serialization.
// * Added and modified files are both part of file_changes.
// * file_changes is at the end of the struct so that a deserializer that just
//   wants to read metadata can stop early.
// * The "required" fields are only for data that is absolutely core to the
//   model. Note that Thrift does allow changing "required" to unqualified.
// * MPath, Id and DateTime fields do not have a reasonable default value, so
//   they must always be either "required" or "optional".
// * The set of keys in file_changes is path-conflict-free (pcf): no changed
//   path is a directory prefix of another path. So file_changes can never have
//   "foo" and "foo/bar" together, but "foo" and "foo1" are OK.
//   * If a directory is replaced by a file, the bonsai changeset will only
//     record the file being added. The directory being deleted is implicit.
//   * This only applies if the potential prefix is changed. Deleted files can
//     have conflicting subdirectory entries recorded for them.
//   * Corollary: The file list in Mercurial is not pcf, so the Bonsai diff is
//     computed separately.
struct BonsaiChangeset {
  1: required list<ChangesetId> parents,
  2: string author,
  3: optional DateTime author_date,
  // Mercurial won't necessarily have a committer, so this is optional.
  4: optional string committer,
  5: optional DateTime committer_date,
  6: string message,
  7: map<string, binary> (rust.type = "sorted_vector_map::SortedVectorMap") extra,
  8: map<MPath, FileChangeOpt> (rust.type = "sorted_vector_map::SortedVectorMap") file_changes,
}

// DateTime fields do not have a reasonable default value! They must
// always be required or optional.
struct DateTime {
  1: required i64 timestamp_secs,
  // Timezones can go up to UTC+13 (which would be represented as -46800), so
  // an i16 can't fit them.
  2: required i32 tz_offset_secs,
}

struct ContentChunkPointer {
  1: ContentChunkId chunk_id,
  2: i64 size,
}

// When a file is chunked, we reprsent it as a list of its chunks, as well as
// its ContentId.
struct ChunkedFileContents {
  // The ContentId is here to ensure we can reproduce the ContentId from the
  // FileContents reprseentation in Mononoke, which would normally require
  // hashing the contents (but we obviously can't do that here, since we don't
  // have the contents).
  1: ContentId content_id,
  2: list<ContentChunkPointer> chunks,
}

union FileContents {
  // Plain uncompressed bytes - WYSIWYG.
  1: binary_bytes Bytes,
  // References to Chunks (stored as FileContents, too).
  2: ChunkedFileContents Chunked,
}

union ContentChunk {
  1: binary_bytes Bytes,
}

// Payload of object which is an alias
union ContentAlias {
  1: ContentId ContentId, // File content alias
}

// Metadata about a file. This includes hahs aliases, or the file's size.
// NOTE: Fields 1 through 5 have always been written by Mononoke, and Mononoke
// expects them to be present when reading ContentMetadata structs back
// from its Filestore. They're marked optional so we can report errors if
// they're absent at runtime (as opposed to letting Thrift give us a default
// value).
struct ContentMetadata {
  // total_size is needed to make GitSha1 meaningful, but generally useful
  1: optional i64 total_size,
  // ContentId we're providing metadata for
  2: optional ContentId content_id,
  3: optional Sha1 sha1,
  4: optional Sha256 sha256,
  // always object type "blob"
  5: optional GitSha1 git_sha1,
}

union RawBundle2 {
  1: binary Bytes,
}

enum FileType {
  Regular = 0,
  Executable = 1,
  Symlink = 2,
}

struct FileChangeOpt {
  // The value being absent here means that the file was deleted.
  1: optional FileChange change,
}

struct FileChange {
  1: required ContentId content_id,
  2: FileType file_type,
  // size is a u64 stored as an i64
  3: required i64 size,
  4: optional CopyInfo copy_from,
}

// This is only used optionally so it is OK to use `required` here.
struct CopyInfo {
  1: required MPath file,
  // cs_id must match one of the parents specified in BonsaiChangeset
  2: required ChangesetId cs_id,
}

struct FileUnode {
  1: list<FileUnodeId> parents,
  2: ContentId content_id,
  3: FileType file_type,
  4: MPathHash path_hash,
  5: ChangesetId linknode,
}

union UnodeEntry {
  1: FileUnodeId File,
  2: ManifestUnodeId Directory,
}

struct ManifestUnode {
  1: list<ManifestUnodeId> parents,
  2: map<MPathElement, UnodeEntry> (rust.type = "sorted_vector_map::SortedVectorMap") subentries,
  3: ChangesetId linknode,
}

struct DeletedManifest {
  1: optional ChangesetId linknode,
  2: map<MPathElement, DeletedManifestId> (rust.type = "sorted_vector_map::SortedVectorMap") subentries,
}

struct FsnodeFile {
  1: ContentId content_id,
  2: FileType file_type,
  // size is a u64 stored as an i64
  3: i64 size,
  4: Sha1 content_sha1,
  5: Sha256 content_sha256,
}

struct FsnodeDirectory {
  1: FsnodeId id,
  2: FsnodeSummary summary,
}

struct FsnodeSummary {
  1: Sha1 simple_format_sha1,
  2: Sha256 simple_format_sha256,
  // Counts and sizes are u64s stored as i64s
  3: i64 child_files_count,
  4: i64 child_files_total_size,
  5: i64 child_dirs_count,
  6: i64 descendant_files_count,
  7: i64 descendant_files_total_size,
}

union FsnodeEntry {
  1: FsnodeFile File,
  2: FsnodeDirectory Directory,
}

// Content-addressed manifest, with metadata useful for filesystem
// implementations.
//
// Fsnodes form a manifest tree, where unique tree content (i.e. the names and
// contents of files and directories, but not their history) is represented by
// a single fsnode.  Fsnode identities change when any file content is changed.
//
// Fsnode metadata includes summary information about the content ID of
// files and manifests, and the number of files and sub-directories within
// directories.
struct Fsnode {
  1: map<MPathElement, FsnodeEntry> (rust.type = "sorted_vector_map::SortedVectorMap") subentries,
  2: FsnodeSummary summary,
}

struct SkeletonManifestDirectory {
  1: SkeletonManifestId id,
  2: SkeletonManifestSummary summary,
}

struct SkeletonManifestSummary {
  1: i64 child_files_count,
  2: i64 child_dirs_count,
  3: i64 descendant_files_count,
  4: i64 descendant_dirs_count,
  5: i32 max_path_len,
  6: i32 max_path_wchar_len,
  7: bool child_case_conflicts,
  8: bool descendant_case_conflicts,
  9: bool child_non_utf8_filenames,
  10: bool descendant_non_utf8_filenames,
  11: bool child_invalid_windows_filenames,
  12: bool descendant_invalid_windows_filenames,
}

struct SkeletonManifestEntry {
  // Present if this is a directory, absent for a file.
  1: optional SkeletonManifestDirectory directory,
}

// Structure-addressed manifest, with metadata useful for traversing manifest
// trees and determining case conflicts.
//
// Skeleton manifests form a manifest tree, where unique tree structure (i.e.
// the names of files and directories, but not their contents or history) is
// represented by a single skeleton manifest.  Skeleton manifest identities
// change when files are added or removed.
struct SkeletonManifest {
  1: map<MPathElement, SkeletonManifestEntry> (rust.type = "sorted_vector_map::SortedVectorMap") subentries,
  2: SkeletonManifestSummary summary,
}

// Structure that holds a commit graph, usually a history of a file
// or a directory hence the name. Semantically it stores list of
// (commit hash, [parent commit hashes]), however it's stored in compressed form
// described below. Compressed form is used to save space.
//
// FastlogBatch has two parts: `latest` and `previous_batches`.
// `previous_batches` field points to another FastlogBatch structures so
// FastlogBatch is a recursive structure. However normally `previous_batches`
// point to degenerate version of FastlogBatch with empty `previous_batches`
// i.e. we have only one level of nesting.
//
// In order to get the full list we need to get latest commits and concatenate
// it with lists from `previous_batches`.
//
// `latest` stores commit hashes and offsets to commit parents
// i.e. if offset is 1, then next commit is a parent of a current commit.
// For example, a list like
//
//  (HASH_A, [HASH_B])
//  (HASH_B, [])
//
//  will be encoded as
//  (HASH_A, [1])  # offset is 1, means next hash
//  (HASH_B, [])
//
//  A list with a merge
//  (HASH_A, [HASH_B, HASH_C])
//  (HASH_B, [])
//  (HASH_C, [])
//
//  will be encoded differently
//  (HASH_A, [1, 2])
//  (HASH_B, [])
//  (HASH_C, [])
//
// Note that offset might point to a commit in a next FastlogBatch or even
// point to batch outside of all previous_batches.
struct FastlogBatch {
  1: list<CompressedHashAndParents> latest,
  2: list<FastlogBatchId> previous_batches,
}

typedef i32 ParentOffset (rust.newtype)

struct CompressedHashAndParents {
  1: ChangesetId cs_id,
  # Offsets can be negative!
  2: list<ParentOffset> parent_offsets,
}

typedef i32 BlameChangeset (rust.newtype)
typedef i32 BlamePath (rust.newtype)

enum BlameRejected {
  TooBig = 0,
  Binary = 1,
}

// Blame V1

struct BlameRange {
  1: i32 length,
  2: ChangesetId csid,
  3: BlamePath path,
  // offset of this range in the origin file (file that introduced this change)
  4: i32 origin_offset,
}

struct Blame {
  1: list<BlameRange> ranges,
  2: list<MPath> paths,
}

union BlameMaybeRejected {
  1: Blame Blame (py3.name = "blame"),
  2: BlameRejected Rejected,
}

// Blame V2

struct BlameRangeV2 {
  // Length (in lines) of this range.  The offset of a range is implicit from
  // the sum of the lengths of the prior ranges.
  1: i32 length,

  // Index into csids of the changeset that introduced these lines.
  2: BlameChangeset csid_index,

  // Index into paths of the path of this file when this line was introduced.
  3: BlamePath path_index,

  // The offset of this range at the time that this line was introduced.
  4: i32 origin_offset,
}

struct BlameDataV2 {
  // A list of ranges that describe when the lines of this file were
  // introduced.
  1: list<BlameRangeV2> ranges,

  // A mapping of integer indexes to changeset IDs that is used to reduce the
  // repetition of data in ranges.
  //
  // Changeset ID indexes are stable for p1 parents, i.e. a changeset ID's
  // index will not change over the history of a file unless the file is merged
  // in a changeset, in which case only the indexes in the first parent of the
  // changeset are preserved.

  // Changesets are removed from this map when all lines that were added in the
  // changeset are moved and none of the ranges reference it.  This means there
  // are gaps in this mapping, and so a map is used.
  2: map<i32, ChangesetId> (rust.type = "sorted_vector_map::SortedVectorMap") csids,

  // The maximum index that is assigned to a changeset id.  This is also the
  // index that would be assigned to the current changeset, as long as the
  // changeset adds new lines.  If the changeset only deletes or merges lines,
  // then this index will not appear in the csids map.
  3: BlameChangeset max_csid_index,

  // The list of paths that this file has been located at.  This is used to
  // reduce repetition of data in ranges.  Since files are not often moved, and
  // for simplicity, this includes all paths the file has ever been located at,
  // even if they are no longer referenced by any of the ranges.
  4: list<MPath> paths,
}

union BlameV2 {
  // This version of the file contains full blame information.
  1: BlameDataV2 full_blame,

  // This version of the file was rejected for blaming.
  2: BlameRejected rejected,
}
