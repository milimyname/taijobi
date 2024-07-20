import Dialog from './command-dialog.svelte';
import Empty from './command-empty.svelte';
import Group from './command-group.svelte';
import Input from './command-input.svelte';
import Item from './command-item.svelte';
import List from './command-list.svelte';
import Separator from './command-separator.svelte';
import Shortcut from './command-shortcut.svelte';
import Root from './command.svelte';
import { Command as CommandPrimitive } from 'cmdk-sv';

const Loading = CommandPrimitive.Loading;

export {
	Root,
	Dialog,
	Empty,
	Group,
	Item,
	Input,
	List,
	Separator,
	Shortcut,
	Loading,
	//
	Root as Command,
	Dialog as CommandDialog,
	Empty as CommandEmpty,
	Group as CommandGroup,
	Item as CommandItem,
	Input as CommandInput,
	List as CommandList,
	Separator as CommandSeparator,
	Shortcut as CommandShortcut,
	Loading as CommandLoading,
};
