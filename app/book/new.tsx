import { useRouter } from 'expo-router';
import { BookForm, type BookFormValues } from '@/components/BookForm';
import { createBook } from '@/features/books/queries';

export default function NewBook() {
  const router = useRouter();

  async function save(values: BookFormValues) {
    const book = await createBook({
      ...values,
      status: 'reading',
      startedAt: new Date(),
    });
    router.replace({ pathname: '/book/[id]', params: { id: String(book.id) } });
  }

  return <BookForm submitLabel="Add book" onSubmit={save} />;
}
