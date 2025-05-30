.. -*- coding: utf-8; mode: rst -*-

.. _VIDIOC_QBUF:

*******************************
ioctl VIDIOC_QBUF, VIDIOC_DQBUF
*******************************

Name
====

VIDIOC_QBUF - VIDIOC_DQBUF - Exchange a buffer with the driver


Synopsis

.. c:function:: int ioctl( int fd, VIDIOC_QBUF, struct v4l2_buffer *argp )
    :name: VIDIOC_QBUF

.. c:function:: int ioctl( int fd, VIDIOC_DQBUF, struct v4l2_buffer *argp )
    :name: VIDIOC_DQBUF


Arguments

``fd``
    File descriptor returned by :ref:`open() <func-open>`.

``argp``
    Pointer to struct :c:type:`v4l2_buffer`.


Description

Applications call the ``VIDIOC_QBUF`` ioctl to enqueue an empty
(capturing) or filled (output) buffer in the driver's incoming queue.
The semantics depend on the selected I/O method.

To enqueue a buffer applications set the ``type`` field of a struct
:c:type:`v4l2_buffer` to the same buffer type as was
previously used with struct :c:type:`v4l2_format` ``type``
and struct :c:type:`v4l2_requestbuffers` ``type``.
Applications must also set the ``index`` field. Valid index numbers
range from zero to the number of buffers allocated with
:ref:`VIDIOC_REQBUFS` (struct
:c:type:`v4l2_requestbuffers` ``count``) minus
one. The contents of the struct :c:type:`v4l2_buffer` returned
by a :ref:`VIDIOC_QUERYBUF` ioctl will do as well.
When the buffer is intended for output (``type`` is
``V4L2_BUF_TYPE_VIDEO_OUTPUT``, ``V4L2_BUF_TYPE_VIDEO_OUTPUT_MPLANE``,
or ``V4L2_BUF_TYPE_VBI_OUTPUT``) applications must also initialize the
``bytesused``, ``field`` and ``timestamp`` fields, see :ref:`buffer`
for details. Applications must also set ``flags`` to 0. The
``reserved2`` and ``reserved`` fields must be set to 0. When using the
``reserved`` field must be set to 0. When using the
:ref:`multi-planar API <planar-apis>`, the ``m.planes`` field must
contain a userspace pointer to a filled-in array of struct
:c:type:`v4l2_plane` and the ``length`` field must be set
to the number of elements in that array.

To enqueue a :ref:`memory mapped <mmap>` buffer applications set the
``memory`` field to ``V4L2_MEMORY_MMAP``. When ``VIDIOC_QBUF`` is called
with a pointer to this structure the driver sets the
``V4L2_BUF_FLAG_MAPPED`` and ``V4L2_BUF_FLAG_QUEUED`` flags and clears
the ``V4L2_BUF_FLAG_DONE`` flag in the ``flags`` field, or it returns an
EINVAL error code.

To enqueue a :ref:`user pointer <userp>` buffer applications set the
``memory`` field to ``V4L2_MEMORY_USERPTR``, the ``m.userptr`` field to
the address of the buffer and ``length`` to its size. When the
multi-planar API is used, ``m.userptr`` and ``length`` members of the
passed array of struct :c:type:`v4l2_plane` have to be used
instead. When ``VIDIOC_QBUF`` is called with a pointer to this structure
the driver sets the ``V4L2_BUF_FLAG_QUEUED`` flag and clears the
``V4L2_BUF_FLAG_MAPPED`` and ``V4L2_BUF_FLAG_DONE`` flags in the
``flags`` field, or it returns an error code. This ioctl locks the
memory pages of the buffer in physical memory, they cannot be swapped
out to disk. Buffers remain locked until dequeued, until the
:ref:`VIDIOC_STREAMOFF <VIDIOC_STREAMON>` or
:ref:`VIDIOC_REQBUFS` ioctl is called, or until the
device is closed.

To enqueue a :ref:`DMABUF <dmabuf>` buffer applications set the
``memory`` field to ``V4L2_MEMORY_DMABUF`` and the ``m.fd`` field to a
file descriptor associated with a DMABUF buffer. When the multi-planar
API is used the ``m.fd`` fields of the passed array of struct
:c:type:`v4l2_plane` have to be used instead. When
``VIDIOC_QBUF`` is called with a pointer to this structure the driver
sets the ``V4L2_BUF_FLAG_QUEUED`` flag and clears the
``V4L2_BUF_FLAG_MAPPED`` and ``V4L2_BUF_FLAG_DONE`` flags in the
``flags`` field, or it returns an error code. This ioctl locks the
buffer. Locking a buffer means passing it to a driver for a hardware
access (usually DMA). If an application accesses (reads/writes) a locked
buffer then the result is undefined. Buffers remain locked until
dequeued, until the :ref:`VIDIOC_STREAMOFF <VIDIOC_STREAMON>` or
:ref:`VIDIOC_REQBUFS` ioctl is called, or until the
device is closed.

Applications call the ``VIDIOC_DQBUF`` ioctl to dequeue a filled
(capturing) or displayed (output) buffer from the driver's outgoing
queue. They just set the ``type``, ``memory`` and ``reserved`` fields of
a struct :c:type:`v4l2_buffer` as above, when
``VIDIOC_DQBUF`` is called with a pointer to this structure the driver
fills the remaining fields or returns an error code. The driver may also
set ``V4L2_BUF_FLAG_ERROR`` in the ``flags`` field. It indicates a
non-critical (recoverable) streaming error. In such case the application
may continue as normal, but should be aware that data in the dequeued
buffer might be corrupted. When using the multi-planar API, the planes
array must be passed in as well.

By default ``VIDIOC_DQBUF`` blocks when no buffer is in the outgoing
queue. When the ``O_NONBLOCK`` flag was given to the
:ref:`open() <func-open>` function, ``VIDIOC_DQBUF`` returns
immediately with an ``EAGAIN`` error code when no buffer is available.

The struct :c:type:`v4l2_buffer` structure is specified in
:ref:`buffer`.

Explicit Synchronization
------------------------

Explicit Synchronization allows us to control the synchronization of
shared buffers from userspace by passing fences to the kernel and/or
receiving them from it. Fences passed to the kernel are named in-fences and
the kernel should wait on them to signal before using the buffer. On the other
side, the kernel can create out-fences for the buffers it queues to the
drivers. Out-fences signal when the driver is finished with buffer, i.e., the
buffer is ready. The fences are represented as a file and passed as a file
descriptor to userspace.

The in-fences are communicated to the kernel at the ``VIDIOC_QBUF`` ioctl
using the ``V4L2_BUF_FLAG_IN_FENCE`` buffer flag and the `fence_fd` field. If
an in-fence needs to be passed to the kernel, `fence_fd` should be set to the
fence file descriptor number and the ``V4L2_BUF_FLAG_IN_FENCE`` should be set
as well. Setting one but not the other will cause ``VIDIOC_QBUF`` to return
with an error. The fence_fd field will be ignored if the
``V4L2_BUF_FLAG_IN_FENCE`` is not set.

The videobuf2-core will guarantee that all buffers queued with an in-fence will
be queued to the drivers in the same order. Fences may signal out of order, so
this guarantee at videobuf2 is necessary to not change ordering. So when
waiting on a fence to signal all buffers queued after will be also block until
that fence signal.

If the in-fence signals with an error the buffer will be marked with
``V4L2_BUF_FLAG_ERROR`` when returned to userspace at ``VIDIOC_DQBUF``.
Even with the error the order of dequeueing the buffers are preserved.

To get an out-fence back from V4L2 the ``V4L2_BUF_FLAG_OUT_FENCE`` flag should
be set to ask for a fence to be attached to the buffer. The out-fence fd is
sent to userspace as a ``VIDIOC_QBUF`` return argument on the `fence_fd` field.

Note the the same `fence_fd` field is used for both sending the in-fence as
input argument to receive the out-fence as a return argument. A buffer can
have both in-fence ond out-fence.

At streamoff the out-fences will either signal normally if the driver waits
for the operations on the buffers to finish or signal with an error if the
driver cancels the pending operations. Buffers with in-fences won't be queued
to the driver if their fences signal. They will be cleaned up.

The ``V4L2_FMT_FLAG_UNORDERED`` flag in ``VIDIOC_ENUM_FMT`` tells userspace
that the  when using this format the order in which buffers are dequeued can
be different from the order in which they were queued.

Ordering is important to fences because it can optimize the pipeline with
other drivers like a DRM/KMS display driver. For example, if a capture from the
camera is happening in an orderly manner one can send the capture buffer
out-fence to the DRM/KMS driver and rest sure that the buffers will be shown on
the screen at the correct order. If an ordered queue can not be set then such
arrangements with other drivers may not be possible.

Return Value

On success 0 is returned, on error -1 and the ``errno`` variable is set
appropriately. The generic error codes are described at the
:ref:`Generic Error Codes <gen-errors>` chapter.

EAGAIN
    Non-blocking I/O has been selected using ``O_NONBLOCK`` and no
    buffer was in the outgoing queue.

EINVAL
    The buffer ``type`` is not supported, or the ``index`` is out of
    bounds, or no buffers have been allocated yet, or the ``userptr`` or
    ``length`` are invalid.

EIO
    ``VIDIOC_DQBUF`` failed due to an internal error. Can also indicate
    temporary problems like signal loss.

    .. note::

       The driver might dequeue an (empty) buffer despite returning
       an error, or even stop capturing. Reusing such buffer may be unsafe
       though and its details (e.g. ``index``) may not be returned either.
       It is recommended that drivers indicate recoverable errors by setting
       the ``V4L2_BUF_FLAG_ERROR`` and returning 0 instead. In that case the
       application should be able to safely reuse the buffer and continue
       streaming.

EPIPE
    ``VIDIOC_DQBUF`` returns this on an empty capture queue for mem2mem
    codecs if a buffer with the ``V4L2_BUF_FLAG_LAST`` was already
    dequeued and no new buffers are expected to become available.
