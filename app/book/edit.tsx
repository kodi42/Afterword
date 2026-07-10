import { useLocalSearchParams, useRouter } from 'expo-router';
import { useLiveQuery } from 'drizzle-orm/expo-sqlite';
import { BookForm, type BookFormValues } from '@/components/BookForm';
import { bookQuery, updateBook } from '@/features/books/queries';
import type { Book } from '@/db/schema';

/** Edit an existing book's title/author/chapters. Reached from the book detail menu. */
export default function EditBook() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const bookId = Number(id);

  const { data } = useLiveQuery(bookQuery(bookId));
  const book = (data?.[0] as Book | undefined) ?? undefined;

  async function save(values: BookFormValues) {
    await updateBook(bookId, values);
    router.back();
  }

  // Wait for the row before mounting the form so fields pre-fill correctly.
  if (!book) return null;

  return (
    <BookForm
      key={book.id}
      initial={{
        title: book.title,
        author: book.author,
        totalChapters: book.totalChapters,
        coverUri: book.coverUri,
      }}
      submitLabel="Save changes"
      onSubmit={save}
    />
  );
}
