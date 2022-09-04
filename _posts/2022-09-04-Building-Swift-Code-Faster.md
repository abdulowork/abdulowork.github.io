---
layout: post
title:  "Building Swift Code Faster"
tags: xcodebuild Xcode build system compilation speed wholemodule incremental
image: /assets/2/title.png
excerpt_separator: <!--more-->
---

![title](/assets/2/title.png.webp)

How do you speed up the build of your Swift project? Do you use `-warn-long-function-bodies` or maybe even `-stats-output-dir`? These can find some compilation performance issues, but how do you truly take your build times to the next level?

In this article, I want to show you how tweaking some build settings can drastically speed up your clean build times.

<!--more-->

Let us start by building Avito with the default Xcode build settings. For the benchmark, I am using `M1 Pro` with `32 GB` RAM. Here is the result:

![measurements_0](/assets/2/measurement_0.png.webp)

So our clean build time is somewhere around 240 seconds. Is that good? Is that bad? Let us compute some stats for our project.

A way to measure the size of the project is to use a [cloc](https://github.com/AlDanial/cloc) utility.<br />
Here is what we got:

- 1 240 000 lines of Swift code
- 100 000 lines of Objective-C code (mostly external dependencies)
- 6000 lines of C code

I would say that 240 seconds is not bad. But can we go faster? Let us switch `SWIFT_COMPILATION_MODE` from `incremental` to `wholemodule` and see where that leads.<br /> 
This change gets us to the following build duration distribution:

![measurements_1](/assets/2/measurement_1.png.webp)

**Now the average build time is 179 seconds. Somehow our build got faster by 25%!**

{% include linked-heading.html heading="How well is your build parallelized?" level=2 %}

To understand why the build became faster, we first need to know the difference between `incremental` and `wholemodule` compilation modes.

The summary is:

- When we build with `incremental`, the build system uses a batch mode for the swift compiler. The batch mode splits each module compilation into multiple jobs and executes those jobs in parallel.
- On the other hand, `wholemodule` runs a mostly single-threaded compilation of the module without splitting it in any way.

So `incremental` looks like it should be faster due to better parallelization, but why does `wholemodule` perform better in the end?
1. `incremental` build is slower because the compiler has to do more work compiling a module in batches rather than compiling a module as a whole which results in some overhead.<br />
1. At the same time, even though the `wholemodule` compilation is single-threaded, many modules still build in parallel, making this mode efficient.

The [compiler documentation](https://github.com/apple/swift/blob/b65e1bb5b566f6509430bc01a494086b3b31769b/docs/CompilerPerformance.md) also makes a note that `wholemodule` could be faster than `incremental` under circumstances where many modules build in parallel:

> It is, therefore, possible that in certain cases (such as with limited available parallelism / many modules built in parallel), building in whole-module mode with optimization disabled can complete in less time than batched primary-file mode

So how well is build at Avito parallelized?<br />
To understand that, we will employ a visualization similar to that introduced in Xcode 14. It allows us to see how many modules build in parallel at a particular time. 

Let us first take a look at Avito built with `incremental` compilation mode:

![incremental](/assets/2/incremental.png.webp)

Here colored rectangles represent heavy Xcode build system invocations: `swiftc`, `ld`, and some other tools such as `actool`. The build seems well parallelized with the `incremental` compilation mode.

Now take a look at the visualization produced with `wholemodule` compilation mode:

![wmo](/assets/2/wmo.png.webp)

We can see where Avito build is faring well and where it could do better. The reason for this specific shape of the graph is our architecture. At first, we build different utilities which don’t have many dependencies, then follow the poorly parallelized parts of the build - monolithic modules. At last, we have feature modules that don’t depend on one another and build in parallel.

Another way to look at build performance is by looking at CPU utilization. The Instruments `CPU Profiler` trace maps to the `wholemodule` graph quite well:

![wmo_with_cpu](/assets/2/wmo_with_cpu.png.webp)

As expected, there is a sag in CPU utilization where parallelization isn’t perfect.

{% include linked-heading.html heading="Squeezing the last bits of build performance" level=2 %}

In an ideal build scenario, all modules would build parallel across all available cores. Unfortunately, mistakes in architecture can make such a goal unattainable.

**However, there is something we can do to make the build more efficient without reengineering everything from scratch.**<br />
What if we try to leverage the best of `wholemodule` and `incremental` simultaneously? We can keep using `wholemodule` where the build process is parallelized well and switch to `incremental` for those monolithic modules in the middle. That leads to the following build distribution:

![measurements_2](/assets/2/measurement_2.png.webp)

**This change gave us another 14 seconds!**
The CPU is loaded much more evenly, and gaps in the build graph are smaller.

![wmo_and_incremental_with_cpu](/assets/2/wmo_and_incremental_with_cpu.png.webp)

{% include linked-heading.html heading="What’s next?" level=2 %}

Here we only looked at clean builds. Next time I will tell you all about the incremental builds at Avito!

Does tweaking compilation modes make your builds faster? How large is your project, and how swiftly does it build? Let me know in the comments!