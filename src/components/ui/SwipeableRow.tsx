import { ReactNode, useRef } from 'react';
import { Text, View, Pressable, StyleSheet } from 'react-native';
import { Swipeable } from 'react-native-gesture-handler';
import { colors, radius, spacing, type } from '@/theme';

type Props = {
  children: ReactNode;
  onEdit?: () => void;
  onDelete?: () => void;
};

/**
 * Wraps a row so swiping it left reveals Edit / Delete actions. Replaces the
 * long-press action sheet. Uses gesture-handler's Swipeable (no reanimated
 * dependency). The row closes itself before firing a callback so the list is
 * settled by the time an edit form or a confirm dialog appears.
 */
export function SwipeableRow({ children, onEdit, onDelete }: Props) {
  const ref = useRef<Swipeable>(null);

  function run(action?: () => void) {
    ref.current?.close();
    action?.();
  }

  function renderRightActions() {
    return (
      <View style={styles.actions}>
        {onEdit ? (
          <Pressable style={[styles.action, styles.edit]} onPress={() => run(onEdit)}>
            <Text style={styles.editLabel}>Edit</Text>
          </Pressable>
        ) : null}
        {onDelete ? (
          <Pressable style={[styles.action, styles.delete]} onPress={() => run(onDelete)}>
            <Text style={styles.deleteLabel}>Delete</Text>
          </Pressable>
        ) : null}
      </View>
    );
  }

  return (
    <Swipeable
      ref={ref}
      renderRightActions={renderRightActions}
      overshootRight={false}
      friction={2}
      rightThreshold={40}
    >
      {children}
    </Swipeable>
  );
}

const styles = StyleSheet.create({
  actions: {
    flexDirection: 'row',
    alignItems: 'stretch',
    marginLeft: spacing.sm,
  },
  action: {
    width: 76,
    alignItems: 'center',
    justifyContent: 'center',
  },
  edit: {
    backgroundColor: colors.accentSoft,
    borderTopLeftRadius: radius.lg,
    borderBottomLeftRadius: radius.lg,
  },
  delete: {
    backgroundColor: colors.danger,
    borderTopRightRadius: radius.lg,
    borderBottomRightRadius: radius.lg,
  },
  editLabel: { ...type.label, color: colors.accent },
  deleteLabel: { ...type.label, color: colors.surface },
});
