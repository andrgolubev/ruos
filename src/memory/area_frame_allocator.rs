use memory::{Frame, FrameAllocator};
use multiboot2::{MemoryAreaIter, MemoryArea};

pub struct AreaFrameAllocator {
    next_free_frame: Frame,
    current_area: Option<&'static MemoryArea>,
    areas: MemoryAreaIter,
    kernel_start: Frame,
    kernel_end: Frame,
    multiboot_start: Frame,
    multiboot_end: Frame
}

impl FrameAllocator for AreaFrameAllocator {
    fn allocate_frame(&mut self) -> Option<Frame> {
        if let Some(area) = self.current_area {
            let frame = Frame{ number: self.next_free_frame.number };
            let current_area_last_frame = {
                let addr = area.base_addr + area.length - 1;
                Frame::from_address(addr as usize)
            };
            if frame > current_area_last_frame {
                self.next_area()
            } else if frame >= self.kernel_start && frame <= self.kernel_end {
                self.next_free_frame = Frame {
                    number: self.kernel_end.number + 1
                };
            } else if frame >= self.multiboot_start && frame <= self.multiboot_end {
                self.next_free_frame = Frame {
                    number: self.multiboot_end.number + 1
                };
            } else {
                self.next_free_frame.number += 1;
                return Some(frame);
            }
            // `frame` was invalid, try again with updated `next_free_frame`
            self.allocate_frame()
        } else {
            return None;
        }
    }

    fn deallocate_frame(&mut self) -> Option<Frame> {
        unimplemented!()
    }
}

impl AreaFrameAllocator {
    pub fn new(
        kernel_start: usize,
        kernel_end: usize,
        multiboot_start: usize,
        multiboot_end: usize,
        memory_areas: MemoryAreaIter) -> AreaFrameAllocator{
        let mut allocator = AreaFrameAllocator {
            next_free_frame: Frame::from_address(0),
            current_area: None,
            areas: memory_areas,
            kernel_start: Frame::from_address(kernel_start),
            kernel_end: Frame::from_address(kernel_end),
            multiboot_start: Frame::from_address(multiboot_start),
            multiboot_end: Frame::from_address(multiboot_end)
        };
        allocator.next_area();
        return allocator;
    }

    fn next_area(&mut self) {
        self.current_area = self.areas.clone().filter(|area| {
            let addr = area.base_addr + area.length - 1;
            return Frame::from_address(addr as usize) >= self.next_free_frame
        }).min_by_key(|area| area.base_addr);
        if let Some(area) = self.current_area {
            let start_frame = Frame::from_address(area.base_addr as usize);
            if self.next_free_frame < start_frame {
                self.next_free_frame = start_frame;
            }
        }
    }
}
