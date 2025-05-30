Linux Filesystems API

The Linux VFS

The Filesystem types
--------------------

.. kernel-doc:: include/linux/fs.h
   :internal:

The Directory Cache
-------------------

.. kernel-doc:: fs/dcache.c
   :export:

.. kernel-doc:: include/linux/dcache.h
   :internal:

Inode Handling
--------------

.. kernel-doc:: fs/inode.c
   :export:

.. kernel-doc:: fs/bad_inode.c
   :export:

Registration and Superblocks
----------------------------

.. kernel-doc:: fs/super.c
   :export:

File Locks
----------

.. kernel-doc:: fs/locks.c
   :export:

.. kernel-doc:: fs/locks.c
   :internal:

Other Functions
---------------

.. kernel-doc:: fs/mpage.c
   :export:

.. kernel-doc:: fs/namei.c
   :export:

.. kernel-doc:: fs/buffer.c
   :export:

.. kernel-doc:: block/bio.c
   :export:

.. kernel-doc:: fs/seq_file.c
   :export:

.. kernel-doc:: fs/filesystems.c
   :export:

.. kernel-doc:: fs/fs-writeback.c
   :export:

.. kernel-doc:: fs/block_dev.c
   :export:

.. kernel-doc:: fs/anon_inodes.c
   :export:

.. kernel-doc:: fs/attr.c
   :export:

.. kernel-doc:: fs/d_path.c
   :export:

.. kernel-doc:: fs/dax.c
   :export:

.. kernel-doc:: fs/direct-io.c
   :export:

.. kernel-doc:: fs/file_table.c
   :export:

.. kernel-doc:: fs/libfs.c
   :export:

.. kernel-doc:: fs/posix_acl.c
   :export:

.. kernel-doc:: fs/stat.c
   :export:

.. kernel-doc:: fs/sync.c
   :export:

.. kernel-doc:: fs/xattr.c
   :export:

The proc filesystem

sysctl interface
----------------

.. kernel-doc:: kernel/sysctl.c
   :export:

proc filesystem interface
-------------------------

.. kernel-doc:: fs/proc/base.c
   :internal:

Events based on file descriptors

.. kernel-doc:: fs/eventfd.c
   :export:

The Filesystem for Exporting Kernel Objects

.. kernel-doc:: fs/sysfs/file.c
   :export:

.. kernel-doc:: fs/sysfs/symlink.c
   :export:

The debugfs filesystem

debugfs interface
-----------------

.. kernel-doc:: fs/debugfs/inode.c
   :export:

.. kernel-doc:: fs/debugfs/file.c
   :export:

The Linux Journalling API

Overview
--------

Details
~~~~~~~

The journalling layer is easy to use. You need to first of all create a
journal_t data structure. There are two calls to do this dependent on
how you decide to allocate the physical media on which the journal
resides. The :c:func:`jbd2_journal_init_inode` call is for journals stored in
filesystem inodes, or the :c:func:`jbd2_journal_init_dev` call can be used
for journal stored on a raw device (in a continuous range of blocks). A
journal_t is a typedef for a struct pointer, so when you are finally
finished make sure you call :c:func:`jbd2_journal_destroy` on it to free up
any used kernel memory.

Once you have got your journal_t object you need to 'mount' or load the
journal file. The journalling layer expects the space for the journal
was already allocated and initialized properly by the userspace tools.
When loading the journal you must call :c:func:`jbd2_journal_load` to process
journal contents. If the client file system detects the journal contents
does not need to be processed (or even need not have valid contents), it
may call :c:func:`jbd2_journal_wipe` to clear the journal contents before
calling :c:func:`jbd2_journal_load`.

Note that jbd2_journal_wipe(..,0) calls
:c:func:`jbd2_journal_skip_recovery` for you if it detects any outstanding
transactions in the journal and similarly :c:func:`jbd2_journal_load` will
call :c:func:`jbd2_journal_recover` if necessary. I would advise reading
:c:func:`ext4_load_journal` in fs/ext4/super.c for examples on this stage.

Now you can go ahead and start modifying the underlying filesystem.
Almost.

You still need to actually journal your filesystem changes, this is done
by wrapping them into transactions. Additionally you also need to wrap
the modification of each of the buffers with calls to the journal layer,
so it knows what the modifications you are actually making are. To do
this use :c:func:`jbd2_journal_start` which returns a transaction handle.

:c:func:`jbd2_journal_start` and its counterpart :c:func:`jbd2_journal_stop`,
which indicates the end of a transaction are nestable calls, so you can
reenter a transaction if necessary, but remember you must call
:c:func:`jbd2_journal_stop` the same number of times as
:c:func:`jbd2_journal_start` before the transaction is completed (or more
accurately leaves the update phase). Ext4/VFS makes use of this feature to
simplify handling of inode dirtying, quota support, etc.

Inside each transaction you need to wrap the modifications to the
individual buffers (blocks). Before you start to modify a buffer you
need to call :c:func:`jbd2_journal_get_create_access()` /
:c:func:`jbd2_journal_get_write_access()` /
:c:func:`jbd2_journal_get_undo_access()` as appropriate, this allows the
journalling layer to copy the unmodified
data if it needs to. After all the buffer may be part of a previously
uncommitted transaction. At this point you are at last ready to modify a
buffer, and once you are have done so you need to call
:c:func:`jbd2_journal_dirty_metadata`. Or if you've asked for access to a
buffer you now know is now longer required to be pushed back on the
device you can call :c:func:`jbd2_journal_forget` in much the same way as you
might have used :c:func:`bforget` in the past.

A :c:func:`jbd2_journal_flush` may be called at any time to commit and
checkpoint all your transactions.

Then at umount time , in your :c:func:`put_super` you can then call
:c:func:`jbd2_journal_destroy` to clean up your in-core journal object.

Unfortunately there a couple of ways the journal layer can cause a
deadlock. The first thing to note is that each task can only have a
single outstanding transaction at any one time, remember nothing commits
until the outermost :c:func:`jbd2_journal_stop`. This means you must complete
the transaction at the end of each file/inode/address etc. operation you
perform, so that the journalling system isn't re-entered on another
journal. Since transactions can't be nested/batched across differing
journals, and another filesystem other than yours (say ext4) may be
modified in a later syscall.

The second case to bear in mind is that :c:func:`jbd2_journal_start` can block
if there isn't enough space in the journal for your transaction (based
on the passed nblocks param) - when it blocks it merely(!) needs to wait
for transactions to complete and be committed from other tasks, so
essentially we are waiting for :c:func:`jbd2_journal_stop`. So to avoid
deadlocks you must treat :c:func:`jbd2_journal_start` /
:c:func:`jbd2_journal_stop` as if they were semaphores and include them in
your semaphore ordering rules to prevent
deadlocks. Note that :c:func:`jbd2_journal_extend` has similar blocking
behaviour to :c:func:`jbd2_journal_start` so you can deadlock here just as
easily as on :c:func:`jbd2_journal_start`.

Try to reserve the right number of blocks the first time. ;-). This will
be the maximum number of blocks you are going to touch in this
transaction. I advise having a look at at least ext4_jbd.h to see the
basis on which ext4 uses to make these decisions.

Another wriggle to watch out for is your on-disk block allocation
strategy. Why? Because, if you do a delete, you need to ensure you
haven't reused any of the freed blocks until the transaction freeing
these blocks commits. If you reused these blocks and crash happens,
there is no way to restore the contents of the reallocated blocks at the
end of the last fully committed transaction. One simple way of doing
this is to mark blocks as free in internal in-memory block allocation
structures only after the transaction freeing them commits. Ext4 uses
journal commit callback for this purpose.

With journal commit callbacks you can ask the journalling layer to call
a callback function when the transaction is finally committed to disk,
so that you can do some of your own management. You ask the journalling
layer for calling the callback by simply setting
``journal->j_commit_callback`` function pointer and that function is
called after each transaction commit. You can also use
``transaction->t_private_list`` for attaching entries to a transaction
that need processing when the transaction commits.

JBD2 also provides a way to block all transaction updates via
:c:func:`jbd2_journal_lock_updates()` /
:c:func:`jbd2_journal_unlock_updates()`. Ext4 uses this when it wants a
window with a clean and stable fs for a moment. E.g.

::


        jbd2_journal_lock_updates() //stop new stuff happening..
        jbd2_journal_flush()        // checkpoint everything.
        ..do stuff on stable fs
        jbd2_journal_unlock_updates() // carry on with filesystem use.

The opportunities for abuse and DOS attacks with this should be obvious,
if you allow unprivileged userspace to trigger codepaths containing
these calls.

Summary
~~~~~~~

Using the journal is a matter of wrapping the different context changes,
being each mount, each modification (transaction) and each changed
buffer to tell the journalling layer about them.

Data Types
----------

The journalling layer uses typedefs to 'hide' the concrete definitions
of the structures used. As a client of the JBD2 layer you can just rely
on the using the pointer as a magic cookie of some sort. Obviously the
hiding is not enforced as this is 'C'.

Structures
~~~~~~~~~~

.. kernel-doc:: include/linux/jbd2.h
   :internal:

Functions
---------

The functions here are split into two groups those that affect a journal
as a whole, and those which are used to manage transactions

Journal Level
~~~~~~~~~~~~~

.. kernel-doc:: fs/jbd2/journal.c
   :export:

.. kernel-doc:: fs/jbd2/recovery.c
   :internal:

Transasction Level
~~~~~~~~~~~~~~~~~~

.. kernel-doc:: fs/jbd2/transaction.c

See also
--------

`Journaling the Linux ext2fs Filesystem, LinuxExpo 98, Stephen
Tweedie <http://kernel.org/pub/linux/kernel/people/sct/ext3/journal-design.ps.gz>`__

`Ext3 Journalling FileSystem, OLS 2000, Dr. Stephen
Tweedie <http://olstrans.sourceforge.net/release/OLS2000-ext3/OLS2000-ext3.html>`__

splice API

splice is a method for moving blocks of data around inside the kernel,
without continually transferring them between the kernel and user space.

.. kernel-doc:: fs/splice.c

pipes API

Pipe interfaces are all for in-kernel (builtin image) use. They are not
exported for use by modules.

.. kernel-doc:: include/linux/pipe_fs_i.h
   :internal:

.. kernel-doc:: fs/pipe.c

Encryption API

A library which filesystems can hook into to support transparent
encryption of files and directories.

.. toctree::
    :maxdepth: 2

    fscrypt
    fsverity
